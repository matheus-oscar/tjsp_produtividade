rm(list = ls()) ; gc(reset = T)
setwd(dirname(rstudioapi::getSourceEditorContext()$path))

# pacotes -----------------------------------------------------------------

library(pdftools)
library(tidyverse)
library(dplyr)
library(stringr)
library(tibble)
library(purrr)
library(openxlsx)
library(gtools)

#VERSÃO QUASE FINAL----

# Função para processar um único arquivo PDF---
processar_pdf <- function(file_path){
  
  cat("\nArquivo", file_path, "sendo processado...\n")
  
  materias <- data.frame(materia_total = c('CÍVEL',
                                           'CRIMINAL',
                                           'EXECUÇÃO FISCAL',
                                           'INFÂNCIA',
                                           'JUIZADO CRIMINAL',
                                           'JUIZADO ESPECIAL',
                                           'JUIZADO FAZENDA PÚBLICA',
                                           'SETOR FAZENDA PÚBLICA'))
  # Ler o PDF e extrair o texto
  texto <- pdf_text(file_path) %>% paste(collapse = " ")
  
  # Padrões para extrair as informações principais
  foro <- str_extract_all(texto, "Foro:.*") %>% unlist() %>% str_remove("Foro: ")
  unidade <- str_extract_all(texto, "Unidade:.*") %>% unlist() %>% str_remove("Unidade: ")
  materia <- str_extract_all(texto, "Matéria:.*") %>% unlist() %>% str_remove("Matéria: ")
  
  # Extrair os valores específicos da seção "Feitos em andamento"
  #remove \n e cria texto corrido com 1 exato espaço entre todas as palavras
  texto_feitos <- str_squish(texto)
  
  #RETIRAR DESCRIÇÃO DOS PDFS 
  #DELIMITAR PROCURA ANTES DE 'Considerações para análise dos dados na tabela de feitos em andamento'
  texto_feitos <- gsub("Considerações\\spara\\sanálise\\sdos\\sdados.*$", "", texto_feitos)
  
  materia_doc <- tibble(foro,
                        unidade,
                        
                        materias %>% 
                          filter(materia_total %in% materia),
                        
                        arquivo = str_remove(file_path, 'data-raw/'),
                        
                        safra = str_extract(caminho, "/[0-9]{6}/"),
                        safra = str_replace_all(safra, "/", ""),
                        
                        regex = NA,
                        feitos_tot = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA CÍVEL
                        civ_proc_conh = NA,
                        civ_exec_tit_extr = NA,
                        civ_cump_sent = NA,
                        civ_cart_prec_rog_ord = NA,
                        civ_feitos_grau_rec = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA CRIMINAL
                        crim_proc_invest = NA,
                        crim_proc_crime_queixas = NA,
                        crim_cart_prec_rog_ord = NA,
                        crim_outros_proced = NA,
                        crim_exec_crim_sivec = NA,
                        crim_exec_crim_saj = NA,
                        crim_feitos_grau_rec = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA EXECUÇÃO FISCAL
                        exec_fiscal_fed = NA,
                        exec_fiscal_est = NA,
                        exec_fiscal_mun = NA,
                        exec_fiscal_precat_andamento = NA,
                        exec_fiscal_total_grau_rec = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA INFÂNCIA
                        inf_outros_proced = NA,
                        inf_juv_infra = NA,
                        inf_juv_civel = NA,
                        inf_precat_andamento = NA,
                        inf_feitos_grau_rec = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA JUIZADO CRIMINAL
                        juiz_crim_proced_fase_prel = NA,
                        juiz_crim_proced_sumariss = NA,
                        juiz_crim_exec = NA,
                        juiz_crim_precat_andamento = NA,
                        juiz_crim_total_grau_rec = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA JUIZADO ESPECIAL
                        juiz_esp_proc_conh = NA,
                        juiz_esp_titulo_extrajud = NA,
                        juiz_esp_cump_sent = NA,
                        juiz_esp_precat_andamento = NA,
                        juiz_esp_total_grau_rec = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA JUIZADO FAZENDA PÚBLICA
                        juiz_faz_proc_conh = NA,
                        juiz_faz_titulo_extrajud = NA,
                        juiz_faz_cump_sent = NA,
                        juiz_faz_precat_andamento = NA,
                        juiz_faz_total_grau_rec = NA,
                        
                        #SUBDIVISÕES DA MATÉRIA SETOR FAZENDA PÚBLICA
                        faz_pub_fazenda_mun = NA,
                        faz_pub_autarquias_fund = NA,
                        faz_pub_fazenda_estad = NA,
                        faz_pub_total_grau_rec = NA) 
  
  for (i in 1:nrow(materia_doc)) { #REGEX DELIMITADO PELOS TEMAS (TEMAS ESTÃO PRESENTES no início e final da string)
    
    if(i == nrow(materia_doc)){
      
      materia_doc$regex[i] = gsub(paste0('.*(Matéria:\\s',materia_doc$materia_total[i],')'), '\\1', texto_feitos)
      materia_doc$feitos_tot[i] = 
        str_extract_all(materia_doc$regex[i], "(?i)\\sTotal\\sde\\sFeitos\\sem\\sAndamento\\s*(\\d|\\.)+") %>% 
        unlist() %>% 
        str_remove_all("\\.") %>% 
        str_extract("\\d+") %>% 
        as.numeric() %>% 
        {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
    }
    
    else{ #PROCURA ENTRE 2 MATÉRIAS
      materia_doc$regex[i] = gsub(paste0('.*(Matéria:\\s',materia_doc$materia_total[i],')\\s*|\\s*(Matéria:\\s', materia_doc$materia_total[i+1],').*$'), '\\1\\2', texto_feitos)
      materia_doc$feitos_tot[i] = 
        str_extract_all(materia_doc$regex[i], "(?i)\\sTotal\\sde\\sFeitos\\sem\\sAndamento\\s*(\\d|\\.)+") %>% 
        unlist() %>% 
        str_remove_all("\\.") %>% 
        str_extract("\\d+") %>% 
        as.numeric() %>% 
        {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
    }}
  
  
  for(i in 1:nrow(materia_doc)){
    
    #AJUSTE PARA CASOS EM QUE O DOCUMENTO NÃO POSSUI INFORMAÇÃO
    if(dim(materia_doc)[1] != 0)  {
      
      if(materia_doc$materia_total[i] == "CÍVEL"){
        
        #SUBDIVISÕES DA MATÉRIA CÍVEL----
        
        materia_doc$civ_proc_conh[i] <- str_extract_all(materia_doc$regex[i],
                                                        "(?i)\\sProcessos\\sde\\sConhecimento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$civ_exec_tit_extr[i] <- str_extract_all(materia_doc$regex[i],
                                                            "(?i)\\sExecuções\\sde\\sTitulo\\sExtrajudicial\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$civ_cump_sent[i] <- str_extract_all(materia_doc$regex[i],
                                                        "(?i)\\sCumprimentos\\sde\\sSentença\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$civ_cart_prec_rog_ord[i] <- str_extract_all(materia_doc$regex[i],
                                                                "(?i)\\sCartas\\sPrecatórias,\\sRogatórias\\sou\\sde\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$civ_feitos_grau_rec[i] <- str_extract_all(materia_doc$regex[i],
                                                              "(?i)\\sFeitos\\sem\\sGrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
      }
      
      if(materia_doc$materia_total[i] == "CRIMINAL"){
        
        #SUBDIVISÕES DA MATÉRIA CRIMINAL----
        
        materia_doc$crim_proc_invest[i] <- str_extract_all(materia_doc$regex[i],
                                                           "(?i)\\sProcedimentos\\sInvestigatórios\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$crim_proc_crime_queixas[i] <- str_extract_all(materia_doc$regex[i],
                                                                  "(?i)\\sProcesso\\scrime\\se\\squeixas\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$crim_cart_prec_rog_ord[i] <- str_extract_all(materia_doc$regex[i],
                                                                 "(?i)\\sCartas\\sPrecatórias,\\sRogatórias\\sou\\sde\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$crim_outros_proced[i] <- str_extract_all(materia_doc$regex[i],
                                                             "(?i)\\sOutros\\sProcedimentos\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$crim_exec_crim_sivec[i] <- str_extract_all(materia_doc$regex[i],
                                                               "(?i)\\Execuções\\scriminais\\s-\\sSIVEC\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$crim_exec_crim_saj[i] <- str_extract_all(materia_doc$regex[i],
                                                             "(?i)\\Execuções\\scriminais\\s-\\sSAJ\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$crim_feitos_grau_rec[i] <- str_extract_all(materia_doc$regex[i],
                                                               "(?i)\\sFeitos\\sem\\sGrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
      }
      
      if(materia_doc$materia_total[i] == "EXECUÇÃO FISCAL"){
        
        #SUBDIVISÕES DA MATÉRIA EXECUÇÃO FISCAL----
        
        materia_doc$exec_fiscal_fed[i] <- str_extract_all(materia_doc$regex[i],
                                                          "(?i)\\Execução\\sFiscal\\sFederal\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$exec_fiscal_est[i] <- str_extract_all(materia_doc$regex[i],
                                                          "(?i)\\Execução\\sFiscal\\sEstadual\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$exec_fiscal_mun[i] <- str_extract_all(materia_doc$regex[i],
                                                          "(?i)\\Execução\\sFiscal\\sMunicipal\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$exec_fiscal_precat_andamento[i] <- str_extract_all(materia_doc$regex[i],
                                                                       "(?i)\\sPrecatória\\sem\\sAndamento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$exec_fiscal_total_grau_rec[i] <- str_extract_all(materia_doc$regex[i],
                                                                     "(?i)\\sTotal\\sem\\sgrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
      }
      
      if(materia_doc$materia_total[i] == "INFÂNCIA"){
        
        #SUBDIVISÕES DA MATÉRIA INFÂNCIA----
        
        materia_doc$inf_outros_proced[i] <- str_extract_all(materia_doc$regex[i],
                                                            "(?i)\\Outros\\sprocedimentos\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$inf_juv_infra[i] <- str_extract_all(materia_doc$regex[i],
                                                        "(?i)\\Infancia\\se\\sJuventude\\s-\\sInfracional\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        
        materia_doc$inf_juv_civel[i] <- str_extract_all(materia_doc$regex[i],
                                                        "(?i)\\Infancia\\se\\sJuventude\\s-\\sCivel\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$inf_precat_andamento[i] <- str_extract_all(materia_doc$regex[i],
                                                               "(?i)\\sPrecatória\\sem\\sAndamento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$inf_feitos_grau_rec[i] <- str_extract_all(materia_doc$regex[i],
                                                              "(?i)\\sFeitos\\sem\\sGrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
      }
      
      if(materia_doc$materia_total[i] == "JUIZADO CRIMINAL"){
        
        #SUBDIVISÕES DA MATÉRIA JUIZADO CRIMINAL----
        
        materia_doc$juiz_crim_proced_fase_prel[i] <- str_extract_all(materia_doc$regex[i],
                                                                     "(?i)\\sProcedimento\\sna\\sfase\\spreliminar\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_crim_proced_sumariss[i] <- str_extract_all(materia_doc$regex[i],
                                                                    "(?i)\\sProcedimento\\sSumaríssimo\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_crim_exec[i] <- str_extract_all(materia_doc$regex[i],
                                                         "(?i)\\Execução\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_crim_precat_andamento[i] <- str_extract_all(materia_doc$regex[i],
                                                                     "(?i)\\sPrecatória\\sem\\sAndamento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_crim_total_grau_rec[i] <- str_extract_all(materia_doc$regex[i],
                                                                   "(?i)\\sTotal\\sem\\sgrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
      }
      
      if(materia_doc$materia_total[i] == "JUIZADO ESPECIAL"){
        
        #SUBDIVISÕES DA MATÉRIA JUIZADO ESPECIAL----
        
        materia_doc$juiz_esp_proc_conh[i] <- str_extract_all(materia_doc$regex[i],
                                                             "(?i)\\sProcesso\\sde\\sConhecimento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_esp_titulo_extrajud[i] <- str_extract_all(materia_doc$regex[i],
                                                                   "(?i)\\sTítulo\\sExtrajudicial\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_esp_cump_sent[i] <- str_extract_all(materia_doc$regex[i],
                                                             "(?i)\\sCumprimento\\sde\\sSentença\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_esp_precat_andamento[i] <- str_extract_all(materia_doc$regex[i],
                                                                    "(?i)\\sPrecatória\\sem\\sAndamento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_esp_total_grau_rec[i] <- str_extract_all(materia_doc$regex[i],
                                                                  "(?i)\\sTotal\\sem\\sgrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
      }
      
      if(materia_doc$materia_total[i] == "JUIZADO FAZENDA PÚBLICA"){
        
        #SUBDIVISÕES DA MATÉRIA JUIZADO FAZENDA PÚBLICA----
        
        materia_doc$juiz_faz_proc_conh[i] <- str_extract_all(materia_doc$regex[i],
                                                             "(?i)\\sProcesso\\sde\\sConhecimento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_faz_titulo_extrajud[i] <- str_extract_all(materia_doc$regex[i],
                                                                   "(?i)\\sTitulo\\sExtrajudicial\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_faz_cump_sent[i] <- str_extract_all(materia_doc$regex[i],
                                                             "(?i)\\sCumprimento\\sde\\sSentença\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_faz_precat_andamento[i] <- str_extract_all(materia_doc$regex[i],
                                                                    "(?i)\\sPrecatória\\sem\\sAndamento\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$juiz_faz_total_grau_rec[i] <- str_extract(materia_doc$regex[i],
                                                              "(?i)\\sTotal\\sem\\sgrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
      }
      
      if(materia_doc$materia_total[i] == "SETOR FAZENDA PÚBLICA"){
        
        #SUBDIVISÕES DA MATÉRIA SETOR FAZENDA PÚBLICA----
        
        materia_doc$faz_pub_fazenda_mun[i] <- str_extract_all(materia_doc$regex[i],
                                                              "(?i)\\sFazenda\\sMunicipal\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$faz_pub_autarquias_fund[i] <- str_extract_all(materia_doc$regex[i],
                                                                  "(?i)\\sAutarquias/fundações\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$faz_pub_fazenda_estad[i] <- str_extract_all(materia_doc$regex[i],
                                                                "(?i)\\sFazenda\\sEstadual\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
        materia_doc$faz_pub_total_grau_rec[i] <- str_extract_all(materia_doc$regex[i],
                                                                 "(?i)\\sTotal\\sem\\sgrau\\sde\\srecurso\\s*(\\d|\\.)+") %>% 
          unlist() %>% 
          str_remove_all("\\.") %>% 
          str_extract("\\d+") %>% 
          as.numeric() %>% 
          {if (length(.) > 0L) . else NA} #CORRIGE OS CASOS EM QUE A SAÍDA É numeric(0)
        
      }
    }
    
  }
  
  materia_doc %<>% 
    mutate(feitos_tot_manual = psum(civ_proc_conh,
                                    civ_exec_tit_extr,
                                    civ_cump_sent,
                                    civ_cart_prec_rog_ord,
                                    civ_feitos_grau_rec,
                                    
                                    crim_proc_invest,
                                    crim_proc_crime_queixas,
                                    crim_cart_prec_rog_ord,
                                    crim_outros_proced,
                                    crim_exec_crim_sivec,
                                    crim_exec_crim_saj,
                                    crim_feitos_grau_rec,
                                    
                                    exec_fiscal_fed,
                                    exec_fiscal_est,
                                    exec_fiscal_mun,
                                    exec_fiscal_precat_andamento,
                                    exec_fiscal_total_grau_rec,
                                    
                                    inf_outros_proced,
                                    inf_juv_infra,
                                    inf_juv_civel,
                                    inf_precat_andamento,
                                    inf_feitos_grau_rec,
                                    
                                    juiz_crim_proced_fase_prel,
                                    juiz_crim_proced_sumariss,
                                    juiz_crim_precat_andamento,
                                    juiz_crim_exec,
                                    juiz_crim_total_grau_rec,
                                    
                                    juiz_esp_proc_conh,
                                    juiz_esp_titulo_extrajud,
                                    juiz_esp_cump_sent,
                                    juiz_esp_precat_andamento,
                                    juiz_esp_total_grau_rec,
                                    
                                    juiz_faz_proc_conh,
                                    juiz_faz_titulo_extrajud,
                                    juiz_faz_cump_sent,
                                    juiz_faz_precat_andamento,
                                    juiz_faz_total_grau_rec,
                                    
                                    faz_pub_fazenda_mun,
                                    faz_pub_autarquias_fund,
                                    faz_pub_fazenda_estad,
                                    faz_pub_total_grau_rec,
                                    
                                    na.rm = T)) %>% 
           
    
    relocate(feitos_tot_manual, .after = feitos_tot) %>% 
    
    rename(materia = materia_total)
  
  cat("\nArquivo", file_path, 'terminou de processar!\n')
  
  #CRIA TIBBLE COM AS INFORMAÇÕES - é necessário? sim! PRESERVA A ESTRUTURA MESMO QUANDO NÃO HÁ DADOS NO PDF
  tibble(materia_doc)

}

# Função que automatiza criação de múltiplos .xlsx ----
processar_pasta_pdfs <- function(pasta_caminho) {
  
  #require(gtools) #Ordenar arquivos usando ordem crescente do número das unidades
  # Listar todos os arquivos PDF na pasta
  arquivos_pdf <- gtools::mixedsort(list.files(pasta_caminho, pattern = "\\.pdf$", full.names = TRUE))#[1:10]
  
  #cat("\nPasta", pasta_caminho, "sendo processada...\n")
  
  # Processar cada arquivo PDF e combinar os resultados em um único data frame
  resultados <- map_df(arquivos_pdf, processar_pdf)
  
  write.xlsx(resultados,
             file = paste0(str_sub(pasta_caminho, end = -8), # -8 para retirar a barra contida no caminho
                           "/foros_unidades_feitos_",
                           str_extract(pasta_caminho, '[0-9]+'),
                           ".xlsx"))
}

# UTILIZAÇÃO----

for (pastas in list.dirs('data-raw/download_auto/', full.names = T, recursive = F)) {
  
  cat("\nProcessando pasta", pastas, "...\n")
  
  processar_pasta_pdfs(pastas)
  
  cat("\nPasta", pastas, "processada!\n")
  
}




