import os
import re
import csv
import requests
import streamlit as st
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import time
from collections import defaultdict
import gc

def validar_safra(safra):
    if not re.fullmatch(r'\d{6}', safra):
        raise ValueError(f"Safra '{safra}' deve estar no formato YYYYMM.")
    try:
        datetime.strptime(safra, '%Y%m')
    except ValueError:
        raise ValueError(f"Safra '{safra}' não representa uma data válida.")

def gerar_lista_safras(safra_inicio, safra_fim):
    validar_safra(safra_inicio)
    validar_safra(safra_fim)
    data_inicio = datetime.strptime(safra_inicio, '%Y%m')
    data_fim = datetime.strptime(safra_fim, '%Y%m')
    if data_inicio > data_fim:
        raise ValueError("A safra inicial deve ser anterior ou igual à safra final.")

    safra_atual = data_inicio
    lista = []
    while safra_atual <= data_fim:
        lista.append(safra_atual.strftime('%Y%m'))
        ano = safra_atual.year + (safra_atual.month // 12)
        mes = (safra_atual.month % 12) + 1
        safra_atual = datetime(ano, mes, 1)
    return lista

def baixar_pdf(codigo, safra, url_base, pasta_safra):
    nome_arquivo_pdf = os.path.join(pasta_safra, f"unidade_{codigo}.pdf")
    if os.path.exists(nome_arquivo_pdf):
        datahora = datetime.fromtimestamp(os.path.getmtime(nome_arquivo_pdf)).strftime("%Y-%m-%d %H:%M:%S")
        return (safra, codigo, "Ignorado", "Arquivo existente", datahora)

    url = f"{url_base}{codigo}&format=pdf"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        with open(nome_arquivo_pdf, 'wb') as f:
            f.write(response.content)
        datahora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        return (safra, codigo, "Sucesso", "Download OK", datahora)
    except requests.RequestException as e:
        datahora = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        return (safra, codigo, "Erro", str(e), datahora)

def download_pdfs_streamlit(safra_inicio, safra_fim, unidade_inicio, unidade_fim, diretorio, max_threads=5):
    inicio_tempo = time.time()
    lista_safras = gerar_lista_safras(safra_inicio, safra_fim)
    codigos = list(range(unidade_inicio, unidade_fim + 1))
    resultados = []
    total_tarefas = len(lista_safras) * len(codigos)
    progresso_total = st.progress(0, text="\n".join(["" for _ in range(3)]))
    contagem_total = 0

    with ThreadPoolExecutor(max_workers=max_threads) as executor:
        for safra in lista_safras:
            pasta_safra = os.path.join(diretorio, safra)
            os.makedirs(pasta_safra, exist_ok=True)
            url_base = (
                f"https://www.tjsp.jus.br/APP/ProdutividadePrimeiraInstancia/Report/RelatorioCorreicao"
                f"?anoMesInicial={safra}01&anoMesFinal={safra}01&codigoUnidade="
            )
            
            progresso_safra = st.progress(0, text=f"Safra {safra} - iniciando...")
            futuros_safra = []
            resultados_safra = []
            inicio_safra = time.time()

            for codigo in codigos:
                futuros_safra.append(executor.submit(baixar_pdf, codigo, safra, url_base, pasta_safra))

            for i, future in enumerate(as_completed(futuros_safra)):
                resultado = future.result()
                resultados.append(resultado)
                resultados_safra.append(resultado)
                contagem_total += 1

                progresso_total.progress(
                    contagem_total / total_tarefas,
                    text=f"Baixando... {contagem_total:,}".replace(",", ".") + f"/{total_tarefas:,}".replace(",", ".") + f" ({int((contagem_total / total_tarefas) * 100):,}".replace(",", ".") + "%)"
                )
                progresso_safra.progress(
                    (i + 1) / len(codigos),
                    text=f"Safra {safra} - {i+1:,}".replace(",", ".") + f"/{len(codigos):,}".replace(",", ".") + f" ({int(((i+1)/len(codigos))*100):,}".replace(",", ".") + "%)"
                )

            fim_safra = time.time()
            duracao_safra = fim_safra - inicio_safra
            
            st.info(f"Tempo para baixar safra {safra}: {duracao_safra:.1f} segundos")

            gc.collect()

    caminho_csv = os.path.join(diretorio, "relatorio_downloads.csv")
    modo_csv = 'a' if os.path.exists(caminho_csv) else 'w'
    with open(caminho_csv, modo_csv, newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        if modo_csv == 'w':
            writer.writerow(["safra", "codigo_unidade", "status", "mensagem", "data_download"])
        writer.writerows(resultados)

    fim_tempo = time.time()
    duracao_total = fim_tempo - inicio_tempo

    st.success(f"Download finalizado em {duracao_total:.1f} segundos!")
    st.download_button("Baixar relatório CSV", data=open(caminho_csv, 'rb'), file_name="relatorio_downloads.csv")

    st.subheader("Relatório de Downloads")
    sucesso = sum(1 for r in resultados if r[2] == "Sucesso")
    ignorado = sum(1 for r in resultados if r[2] == "Ignorado")
    erro = sum(1 for r in resultados if r[2] == "Erro")

    st.info(f"Total de arquivos baixados com sucesso: {sucesso:,}".replace(",", "."))
    st.info(f"Total de arquivos ignorados (já existiam): {ignorado:,}".replace(",", "."))
    st.info(f"Total de erros durante o download: {erro:,}".replace(",", "."))

    with st.expander("Detalhes por Safra", expanded=True):
        logs_por_safra = defaultdict(list)
        for safra, cod, status, msg, datahora in resultados:
            logs_por_safra[safra].append((cod, status, msg, datahora))

        st.markdown("<div style='max-height: 300px; overflow-y: auto;'>", unsafe_allow_html=True)
        for safra in sorted(logs_por_safra):
            st.markdown(f"<strong>Safra {safra}</strong>", unsafe_allow_html=True)
            for cod, status, msg, datahora in sorted(logs_por_safra[safra]):
                st.markdown(f"Unidade {cod:,}".replace(",", ".") + f" - {status} - {datahora}")
                if status != "Sucesso":
                    st.warning(msg)
        st.markdown("</div>", unsafe_allow_html=True)

# --- INTERFACE STREAMLIT ---
st.title("Produtividade TJSP v12_0")
st.markdown("Download dos relatórios de produtividade do TJSP em PDF")

with st.form("formulario"):
    safra_inicio = st.text_input("Safra Inicial (YYYYMM)", value="202401")
    safra_fim = st.text_input("Safra Final (YYYYMM)", value="202412")
    unidade_inicio = st.number_input("Código da Unidade Inicial", value=1, step=1)
    unidade_fim = st.number_input("Código da Unidade Final (Máximo sugerido: 5200)", value=5200, step=1)
    diretorio = st.text_input("Diretório de destino", value="relatorios")
    max_threads = st.slider("Nº de downloads simultâneos", 1, 10, value=5)
    submit = st.form_submit_button("Iniciar Download")

if submit:
    try:
        download_pdfs_streamlit(
            safra_inicio, safra_fim,
            int(unidade_inicio), int(unidade_fim),
            diretorio, max_threads
        )
    except Exception as e:
        st.error(f"Erro: {e}")
