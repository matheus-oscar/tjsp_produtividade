import os
import re
import gc
import time
import numpy as np
import pandas as pd
from PyPDF2 import PdfReader
from concurrent.futures import ThreadPoolExecutor, as_completed
from natsort import natsorted
from tqdm import tqdm
import multiprocessing
import streamlit as st

# --- Constantes ---
MATERIAS = [
    "CÍVEL", "CRIMINAL", "EXECUÇÃO FISCAL", "INFÂNCIA",
    "JUIZADO CRIMINAL", "JUIZADO ESPECIAL",
    "JUIZADO FAZENDA PÚBLICA", "SETOR FAZENDA PÚBLICA"
]

PADRAO_MATERIA = re.compile(
    r"Foro:\s*(.+?)\s+Unidade:\s*(.+?)\s+Matéria:\s*"
    r"(CÍVEL|CRIMINAL|EXECUÇÃO FISCAL|INFÂNCIA|JUIZADO CRIMINAL|"
    r"JUIZADO ESPECIAL|JUIZADO FAZENDA PÚBLICA|SETOR FAZENDA PÚBLICA)",
    flags=re.IGNORECASE
)

PADRAO_FEITOS = re.compile(r"(?i)\bTotal\s+de\s+Feitos\s+em\s+Andamento\s*(\d[\d\.]*)")

# --- Extração de texto do PDF ---
def extrair_texto_pdf(file_path):
    try:
        reader = PdfReader(file_path)
        texto = " ".join(
            t.replace('\n', ' ').strip()
            for page in reader.pages
            for t in [page.extract_text()]
            if t
        )
        return re.sub(r"Considerações\s+para\s+análise\s+dos\s+dados.*$", "", texto, flags=re.IGNORECASE)
    except Exception as e:
        st.error(f"Erro ao extrair texto de {file_path}: {e}")
        return ""

# --- Extração estruturada por bloco ---
def extrair_blocos_completo(texto):
    matches = list(PADRAO_MATERIA.finditer(texto))
    blocos = []
    for i, m in enumerate(matches):
        start_idx = m.start()
        end_idx = matches[i + 1].start() if i + 1 < len(matches) else len(texto)
        bloco = texto[start_idx:end_idx]

        feitos = PADRAO_FEITOS.search(bloco)
        feitos_tot = int(feitos.group(1).replace(".", "")) if feitos else np.nan

        blocos.append({
            "Foro": m.group(1).strip(),
            "Unidade": m.group(2).strip(),
            "Matéria": m.group(3).strip(),
            "regex": bloco.strip(),
            "feitos_tot": feitos_tot
        })

    return blocos

# --- Processamento individual de PDF ---
def processar_pdf(nome_arquivo, caminho_pdf, safra):
    texto = extrair_texto_pdf(caminho_pdf)
    if not texto.strip():
        return []

    blocos = extrair_blocos_completo(texto)
    for bloco in blocos:
        bloco["Safra"] = safra
        bloco["Arquivo"] = nome_arquivo
    return blocos

# --- Processamento em lote ---
def processar_pdfs_em_lote(pasta_base, max_threads=None):
    if not os.path.exists(pasta_base):
        st.error(f"Pasta '{pasta_base}' não encontrada.")
        return pd.DataFrame()

    if max_threads is None:
        max_threads = max(1, multiprocessing.cpu_count() - 1)

    safras = [s for s in os.listdir(pasta_base) if os.path.isdir(os.path.join(pasta_base, s))]
    todos_dados = []

    for safra in safras:
        st.write(f"\n📂 Safra: {safra}")
        pasta_safra = os.path.join(pasta_base, safra)
        arquivos_pdf = natsorted([f for f in os.listdir(pasta_safra) if f.endswith(".pdf")])
        resultados = []

        with ThreadPoolExecutor(max_workers=max_threads) as executor:
            futuros = [
                executor.submit(processar_pdf, nome, os.path.join(pasta_safra, nome), safra)
                for nome in arquivos_pdf
            ]

            for futuro in tqdm(as_completed(futuros), total=len(futuros), desc=f"Processando {safra}"):
                resultado = futuro.result()
                if resultado:
                    resultados.extend(resultado)

        df_safra = pd.DataFrame(resultados)
        df_safra["feitos_tot"] = pd.to_numeric(df_safra["feitos_tot"], errors="coerce").astype("Int64")
        todos_dados.append(df_safra)

        del resultados, df_safra
        gc.collect()

    if todos_dados:
        df_final = pd.concat(todos_dados, ignore_index=True)
        colunas = ["Foro", "Unidade", "Matéria", "Arquivo", "regex", "Safra", "feitos_tot"]
        return df_final[colunas]
    else:
        return pd.DataFrame()

# --- Interface Streamlit ---
st.title("🔍 Parsing de PDFs de Produtividade TJSP")

pasta = st.text_input("Caminho da pasta base (com subpastas por safra):", "data-raw")
threads = st.slider("Número de threads para paralelismo:", 1, 10, value=5)

if st.button("📁 Processar PDFs"):
    with st.spinner("Processando todos os PDFs..."):
        df_resultado = processar_pdfs_em_lote(pasta, threads)

    if not df_resultado.empty:
        st.success(f"Processamento finalizado. Total de registros: {len(df_resultado)}")
        st.dataframe(df_resultado)

        csv_path = os.path.join(pasta, "foros_unidades_feitos_geral_PY.csv")
        df_resultado.to_csv(csv_path, index=False, encoding="utf-8-sig")
        st.success(f"CSV salvo em: {csv_path}")
    else:
        st.warning("Nenhum dado consolidado.")
