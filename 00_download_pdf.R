rm(list = ls()) ; gc(reset = T)
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

source('../Pacote R/0. Funcoes V6.R', encoding = 'UTF-8')

## Função para baixar os arquivos em pdf dos relatórios da Corregedoria do TJSP para a Primeira Instância

# pacotes -----------------------------------------------------------------

library(httr)
library(purrr)

# função para baixar os pdfs de produtividade por vara primeira instância

download_pdfs <- function(ano_inicio,ano_fim,codigo_unidade_inicial, codigo_unidade_final, diretorio) {
  # Verificar se o diretório existe, se não, criar
  if (!dir.exists(diretorio)) {
    dir.create(diretorio, recursive = TRUE)
  }
  
  url_base <- paste0("https://www.tjsp.jus.br/APP/ProdutividadePrimeiraInstancia/Report/RelatorioCorreicao?anoMesInicial=",ano_inicio,"01&anoMesFinal=",ano_fim,"01&codigoUnidade=")
  
  for (codigo in codigo_unidade_inicial:codigo_unidade_final) {
    # Modificar a URL com o código da unidade atual
    url <- paste0(url_base, codigo, "&format=pdf")
    
    # Definir o nome do arquivo PDF
    nome_arquivo_pdf <- paste0(diretorio, "/unidade_", codigo, ".pdf")
    
    # Baixar o PDF
    tryCatch({
      download.file(url, nome_arquivo_pdf, mode = "wb")
      message("Baixado: ", nome_arquivo_pdf)
    }, error = function(e) {
      message("Erro ao baixar: ", nome_arquivo_pdf)
    }
    )
  }
}

# AUTOMATIZAR DOWNLOAD----

for (i in str_sub(str_remove_all(as.character(seq(as.Date("2022/1/1"), floor_date(Sys.Date(), unit = 'month') - months(2), #REMOVE MÊS ATUAL
                                          'month')),'-'), end = 6)) {
  
  # print(i)
  
  
  download_pdfs(ano_inicio = i,
                ano_fim = i,
                codigo_unidade_inicial = 1,
                codigo_unidade_final = 5200, #AJUSTAR AQUI
                diretorio = paste0('data-raw/download_auto/',
                                   i))
}




