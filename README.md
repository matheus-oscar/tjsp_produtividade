# Web Scraping Produtividade do TJSP em 1ª Instância

O objetivo desse projeto é extrair e estruturar os dados dos relatórios públicos de produtividade divulgados mensalmente pelo Tribunal de Justiça de São Paulo. Esses dados são disponibilizados em formato PDF, de maneira não estruturada, e foi necessário fazer o web scraping nos milhares de relatórios divulgados. 

Os dados do TJSP estão disponíveis nesse [link](https://www.tjsp.jus.br/produtividadeweb/).

O programa baixa todos os PDF's desejados, separando-os por safra (YYYYMM), e depois extrai todas as informações desejadas. Além dos Jupyter Notebooks, foram disponibilizados 2 scripts que replicam essas funcionalidades, mas rodam um app Streamlit e realizam as funções de download e parsing dos arquivos. Cada um gera 1 arquivo csv: um com o log dos downloads para registrar sucessos, falhas e evitar que PDF's já existentes sejam baixados novamente, e outro com os dados já estruturados, contendo as informações de Foro, Unidade, Matéria, Safra, Total de Feitos em Andamento', além do trecho, extraído por regex, de onde essas informações foram extraídas de tabelas dos PDF's.

Para rodar os apps, basta digitar o comando `streamlit run nome_do_app.py`


O próximo passo é extrair as subdivisões presentes dentro de cada matéria, como é o caso da matéria "CIVEL", onde encontramos execuções de título extrajudicial, cumprimentos de sentença, cartas precatórias, rogatórias ou de ordem e feitos em grau de recurso. Para isso, será reaproveitada a coluna *regex*, que contém apenas o trecho de interesse.


