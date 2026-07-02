;;; ==========================================================================
;;; QUADRO.lsp — Quadros de Rede Eletrica (MAIUSCULAS AUTOMATICAS)
;;; Comando: QUADRO
;;; Compativel com AutoCAD e NanoCAD
;;; ==========================================================================
(vl-load-com)
(setq *Q_ESCOLHA* "q1"  *DCL_VALS* nil)

;; --------------------------------------------------------------------------
;; FUNCAO: caminho de arquivo DCL temporario fixo
;; --------------------------------------------------------------------------
(defun QuadroTmpFile (nome / tmp)
  (setq tmp (getenv "TEMP"))
  (if (not tmp) (setq tmp (getenv "TMP")))
  (if (not tmp) (setq tmp "C:\\Temp"))
  (strcat tmp "\\" nome ".dcl")
)

;; --------------------------------------------------------------------------
;; FUNCOES DE EDICAO / ATUALIZACAO DE BLOCO
;; --------------------------------------------------------------------------
(defun ObterAtributosBloco (blk_ent / ent edata lst tag val)
  (setq ent (entnext blk_ent))
  (while (and ent (= (cdr (assoc 0 (setq edata (entget ent)))) "ATTRIB"))
    (setq tag (cdr (assoc 2 edata)))
    (setq val (cdr (assoc 1 edata)))
    (setq lst (cons (cons tag val) lst))
    (setq ent (entnext ent))
  )
  lst
)

(defun AtualizarAtributosBloco (blk_ent vals / ent edata tag new_val)
  (setq ent (entnext blk_ent))
  (while (and ent (= (cdr (assoc 0 (setq edata (entget ent)))) "ATTRIB"))
    (setq tag (cdr (assoc 2 edata)))
    (if (setq new_val (assoc tag vals))
      (progn
        (setq edata (subst (cons 1 (cdr new_val)) (assoc 1 edata) edata))
        (entmod edata)
      )
    )
    (setq ent (entnext ent))
  )
  (entupd blk_ent)
)

(defun InitDclTile (key tag default is_toggle atts / val)
  (if atts
    (progn
      (setq val (cdr (assoc tag atts)))
      (if (not val) (setq val ""))
      (if is_toggle
        (set_tile key (if (= val "X") "1" "0"))
        (set_tile key val)
      )
    )
    (set_tile key default)
  )
)

;; --------------------------------------------------------------------------
;; FUNCOES DE DESENHO (FUNDO, LINHAS, TEXTOS E ATRIBUTOS)
;; --------------------------------------------------------------------------
(defun CriarFundoBranco (w h)
  (entmake (list
    '(0 . "SOLID") '(100 . "AcDbEntity") '(8 . "0") '(62 . 7)
    '(420 . 16777215) '(100 . "AcDbTrace")
    '(10 0.0 0.0 0.0) (list 11 w 0.0 0.0) (list 12 0.0 h 0.0) (list 13 w h 0.0)
  ))
)
(defun CriarLinha (x1 y1 x2 y2 cor)
  (entmake (list
    '(0 . "LINE") '(100 . "AcDbEntity") '(8 . "0") (cons 62 cor)
    '(100 . "AcDbLine")
    (list 10 x1 y1 0.0) (list 11 x2 y2 0.0)
  ))
)
(defun CriarRetangulo (x1 y1 x2 y2 cor)
  (CriarLinha x1 y1 x2 y1 cor)
  (CriarLinha x2 y1 x2 y2 cor)
  (CriarLinha x2 y2 x1 y2 cor)
  (CriarLinha x1 y2 x1 y1 cor)
)
(defun CriarTexto (txt x y h cor)
  (entmake (list
    '(0 . "TEXT") '(100 . "AcDbEntity") '(8 . "0") (cons 62 cor)
    '(100 . "AcDbText")
    (list 10 x y 0.0) (cons 40 h) (cons 1 txt)
    '(100 . "AcDbText")
  ))
)
(defun CriarAtt (tag x y h padrao cor)
  (entmake (list
    '(0 . "ATTDEF") '(100 . "AcDbEntity") '(8 . "0") (cons 62 cor)
    '(100 . "AcDbText")
    (list 10 x y 0.0) (cons 40 h) (cons 1 padrao)
    '(100 . "AcDbAttributeDefinition")
    (cons 2 tag) (cons 3 tag) '(70 . 0) '(74 . 0)
  ))
)
(defun CriarRetAtt (tag x1 y1 x2 y2 padrao h cor)
  (CriarRetangulo x1 y1 x2 y2 cor)
  (CriarAtt tag (+ x1 0.5) (+ y1 0.3) h padrao cor)
)
(defun CriarCaixaAtt (tag x y label cor h_txt / bs)
  (setq bs (* h_txt 1.5))
  (CriarRetangulo x y (+ x bs) (+ y bs) cor)
  (CriarAtt tag (+ x (* bs 0.1)) (+ y (* bs 0.15)) (* bs 0.68) "" cor)
  (if (/= label "")
    (CriarTexto label (+ x bs 0.5) (+ y (* bs 0.1)) h_txt cor)
  )
)

;; --------------------------------------------------------------------------
;; BLOCOS DOS QUADROS (GerarQ1 a GerarQ4)
;; --------------------------------------------------------------------------
(defun GerarQ1 ( / W H C ht hos)
  (setq W 84.1105  H 62.6078  C 7  ht 1.5875  hos 2.3813)
  (CriarFundoBranco W H)
  (CriarRetangulo 0 0 W H C)
  (CriarLinha 0 54.0 W 54.0 C)
  (CriarLinha 0 32.0 W 32.0 C)
  (CriarLinha 0 16.0 W 16.0 C)
  (CriarLinha 0 10.0 W 10.0 C)
  (CriarLinha 44.0 32.0 44.0 54.0 C)
  (CriarTexto "OS:" 19.0 57.8 hos C)
  (CriarAtt "OS" 27.5 57.8 hos "" C)
  (CriarTexto "DESLOCAMENTO/AFASTAMENTO" 1.0 52.0 ht C)
  (CriarCaixaAtt "C_GAR" 1.0 47.5 "Poste em frente a garagem"        C ht)
  (CriarCaixaAtt "C_VIA" 1.0 43.0 "Poste/Rede em via Publica"        C ht)
  (CriarCaixaAtt "C_EDI" 1.0 38.5 "Poste/Rede proximo de edificacao" C ht)
  (CriarCaixaAtt "C_TER" 1.0 34.0 "Poste/Rede em terreno de Terceiro" C ht)
  (CriarTexto "MELHORIA DE REDE" 45.0 52.0 ht C)
  (CriarCaixaAtt "C_ISO" 45.0 47.5 "Isolamento de Rede"   C ht)
  (CriarCaixaAtt "C_DAN" 45.0 43.0 "Poste Danificado"     C ht)
  (CriarCaixaAtt "C_FOR" 45.0 38.5 "Poste Fora de Padrao" C ht)
  (CriarCaixaAtt "C_MAD" 45.0 34.0 "Poste de Madeira"     C ht)
  (CriarTexto "DISTANCIAS"  1.0 30.5 ht C)
  (CriarTexto "ATUAL"      26.0 30.5 ht C)
  (CriarTexto "FUTURA"     35.0 30.5 ht C)
  (CriarTexto "RISCO"      55.0 30.5 ht C)
  (CriarTexto "BT x Parede"          1.0 28.0 ht C)
  (CriarRetAtt "D_BTA" 24.5 26.8 33.0 29.5 "" ht C)
  (CriarRetAtt "D_BTF" 33.5 26.8 42.0 29.5 "" ht C)
  (CriarTexto "BT x Marquise/Outro"  1.0 25.3 ht C)
  (CriarRetAtt "D_BMA" 24.5 24.1 33.0 26.8 "" ht C)
  (CriarRetAtt "D_BMF" 33.5 24.1 42.0 26.8 "" ht C)
  (CriarTexto "MT x Parede"          1.0 22.6 ht C)
  (CriarRetAtt "D_MTA" 24.5 21.4 33.0 24.1 "SOBRE" ht C)
  (CriarRetAtt "D_MTF" 33.5 21.4 42.0 24.1 "2.10m" ht C)
  (CriarTexto "MT x Marquise/Outro"  1.0 19.9 ht C)
  (CriarRetAtt "D_MMA" 24.5 18.7 33.0 21.4 "" ht C)
  (CriarRetAtt "D_MMF" 33.5 18.7 42.0 21.4 "" ht C)
  (CriarTexto "LARGURA DA CALCADA"   1.0 17.2 ht C)
  (CriarRetAtt "D_LAR" 24.5 16.2 40.0 18.7 "" ht C)
  (CriarCaixaAtt "R_NEN" 44.5 26.8 "NENHUM" C ht)
  (CriarCaixaAtt "R_LEV" 61.0 26.8 "LEVE"   C ht)
  (CriarCaixaAtt "R_MED" 44.5 23.5 "MEDIO"  C ht)
  (CriarCaixaAtt "R_GRA" 61.0 23.5 "GRAVE"  C ht)
  (CriarTexto "COORDENADAS:" 44.5 21.5 ht C)
  (CriarTexto "X:" 44.5 19.0 ht C)
  (CriarAtt "CX" 47.5 19.0 ht "" C)
  (CriarTexto "Y:" 44.5 17.0 ht C)
  (CriarAtt "CY" 47.5 17.0 ht "" C)
  (CriarTexto "HOUVE AVANCO POR PARTE SOLICITANTE?" 1.0 14.3 ht C)
  (CriarCaixaAtt "A_SIM" 47.5 12.8 "SIM" C ht)
  (CriarCaixaAtt "A_NAO" 59.5 12.8 "NAO" C ht)
  (CriarTexto "SIMULADO ELABORADO ANTERIORMENTE?" 1.0 11.3 ht C)
  (CriarCaixaAtt "S_SIM" 47.5 10.0 "SIM" C ht)
  (CriarCaixaAtt "S_NAO" 59.5 10.0 "NAO" C ht)
  (CriarTexto "OS" 71.5 11.3 ht C)
  (CriarRetAtt "S_OS" 74.5 10.0 82.5 12.5 "" ht C)
  (CriarTexto "OBS.:" 1.0 8.5 ht C)
  (CriarRetangulo 1.0 0.3 83.0 9.7 C)
  (CriarAtt "OBS" 2.0 0.8 ht "" C)
)

(defun GerarQ2 ( / W H C ht hos)
  (setq W 99.2124  H 52.8066  C 7  ht 1.5875  hos 2.3813)
  (CriarFundoBranco W H)
  (CriarRetangulo 0 0 W H C)
  (CriarLinha 0 49.5 W 49.5 C)
  (CriarLinha 0 44.5 W 44.5 C)
  (CriarLinha 0 38.5 W 38.5 C)
  (CriarLinha 0 30.5 W 30.5 C)
  (CriarLinha 0 22.0 W 22.0 C)
  (CriarLinha 0 16.5 W 16.5 C)
  (CriarLinha 0  7.0 W  7.0 C)
  (CriarLinha 66.0 44.5 66.0 49.5 C)
  (CriarLinha 66.0 38.5 66.0 44.5 C)
  (CriarLinha 66.0 30.5 66.0 38.5 C)
  (CriarLinha 66.0 22.0 66.0 30.5 C)
  (CriarLinha 53.0  0.0 53.0  7.0 C)
  (CriarTexto "OS:" 34.0 50.5 hos C)
  (CriarAtt "OS" 42.5 50.5 hos "" C)
  (CriarTexto "FINALIDADE" 1.0 48.0 ht C)
  (CriarCaixaAtt "C_LN" 1.0  45.2 "LIGACAO NOVA"    C ht)
  (CriarCaixaAtt "C_AC" 22.0 45.2 "AUMENTO DE CARGA" C ht)
  (CriarTexto "RS:" 53.0 46.5 ht C)
  (CriarRetAtt "RS" 56.5 44.8 65.0 47.8 "" ht C)
  (CriarTexto "UC EXISTENTE" 67.0 48.0 ht C)
  (CriarRetAtt "UC_EX" 67.0 44.8 97.5 47.8 "" ht C)
  (CriarTexto "QUANTIDADE DE LIGACOES" 1.0 43.2 ht C)
  (CriarCaixaAtt "C_1P" 1.0  39.7 "1 PONTO"    C ht)
  (CriarCaixaAtt "C_NP" 18.0 39.7 "NOVO PONTO" C ht)
  (CriarCaixaAtt "C_AG" 38.0 39.7 "AGRUPADA"   C ht)
  (CriarTexto "CARGA INSTALADA TOTAL" 67.0 43.2 ht C)
  (CriarRetAtt "CARGA" 67.0 39.0 97.5 42.5 "" ht C)
  (CriarTexto "TIPO DE LIGACAO" 1.0 37.2 ht C)
  (CriarCaixaAtt "C_MO" 1.0  33.5 "MONOFASICA" C ht)
  (CriarCaixaAtt "C_TR" 21.0 33.5 "TRIFASICA"  C ht)
  (CriarTexto "ORCAR MEDIDOR" 41.5 37.2 ht C)
  (CriarCaixaAtt "C_OMS" 41.5 33.5 "SIM" C ht)
  (CriarCaixaAtt "C_OMN" 51.5 33.5 "NAO" C ht)
  (CriarTexto "DISJUNTOR" 67.0 37.2 ht C)
  (CriarRetAtt "DISJ" 67.0 31.0 97.5 37.0 "32A" ht C)
  (CriarTexto "RAMO DA ATIVIDADE" 1.0 29.3 ht C)
  (CriarCaixaAtt "C_RE" 1.0  26.5 "RESIDENCIAL"   C ht)
  (CriarCaixaAtt "C_CM" 1.0  23.8 "COMERCIAL"     C ht)
  (CriarCaixaAtt "C_IN" 1.0  22.2 "INDUSTRIAL"    C ht)
  (CriarCaixaAtt "C_CO" 20.0 26.5 "CANT. OBRAS"   C ht)
  (CriarCaixaAtt "C_PR" 20.0 23.8 "PROVISORIO"    C ht)
  (CriarCaixaAtt "C_IL" 20.0 22.2 "ILUM. PUBLICA" C ht)
  (CriarCaixaAtt "C_PO" 42.0 26.5 "POCO"          C ht)
  (CriarCaixaAtt "C_IR" 42.0 23.8 "IRRIGANTE"     C ht)
  (CriarCaixaAtt "C_GE" 42.0 22.2 "GERACAO"       C ht)
  (CriarTexto "MONOFASICA:" 67.0 27.5 ht C)
  (CriarRetAtt "MONO_CV" 81.0 26.0 93.5 28.5 "" ht C)
  (CriarTexto "CV" 94.0 26.5 ht C)
  (CriarTexto "TRIFASICA:"  67.0 25.0 ht C)
  (CriarRetAtt "TRIF_CV" 81.0 23.5 93.5 26.0 "" ht C)
  (CriarTexto "CV" 94.0 24.0 ht C)
  (CriarTexto "TOTAL:"      67.0 22.5 ht C)
  (CriarRetAtt "TOT_CV"  81.0 22.2 93.5 24.5 "" ht C)
  (CriarTexto "CV" 94.0 22.5 ht C)
  (CriarTexto "COORDENADAS:" 1.0 20.3 ht C)
  (CriarTexto "X:" 24.0 20.3 ht C)
  (CriarRetAtt "CX" 27.0 17.8 50.0 20.8 "" ht C)
  (CriarTexto "Y:" 52.0 20.3 ht C)
  (CriarRetAtt "CY" 55.0 17.8 78.0 20.8 "" ht C)
  (CriarTexto "OBS.:" 1.0 15.3 ht C)
  (CriarRetangulo 1.0 7.3 97.5 14.8 C)
  (CriarAtt "OBS" 2.0 8.0 ht "" C)
  (CriarTexto "TRAFO EXCLUSIVO" 1.0 5.5 ht C)
  (CriarCaixaAtt "C_TEN" 1.0  2.5 "NAO" C ht)
  (CriarCaixaAtt "C_TES" 14.0 2.5 "SIM" C ht)
  (CriarTexto "POTENCIA" 55.0 5.5 ht C)
  (CriarRetAtt "POTENCIA" 69.0 2.5 97.5 5.5 "" ht C)
)

(defun GerarQ3 ( / W H C ht hos)
  (setq W 125.0205  H 33.9028  C 1  ht 2.0100  hos 3.0)
  (CriarFundoBranco W H)
  (CriarRetangulo 0 0 W H C)
  (CriarLinha 0 27.0 W 27.0 C)
  (CriarLinha 0 20.0 W 20.0 C)
  (CriarLinha 0 13.5 W 13.5 C)
  (CriarLinha 0  6.7 W  6.7 C)
  (CriarLinha 62.5 27.0 62.5 H C)
  (CriarTexto "PE" 3.0 29.0 hos C)
  (CriarAtt "PE" 9.0 29.0 hos "" C)
  (CriarTexto "OS:" 65.0 29.0 hos C)
  (CriarAtt "OS" 74.5 29.0 hos "" C)
  (CriarCaixaAtt "CHK_TRAFO" 3.0 22.1 "TRAFO PARTICULAR" C ht)
  (CriarRetAtt "TRAFO_KVA" 87.0 21.5 112.0 25.5 "" ht C)
  (CriarTexto "KVA" 112.5 22.5 ht C)
  (CriarTexto "CARGA INSTALADA:" 3.0 16.5 ht C)
  (CriarAtt "CARGA" 34.0 16.5 ht "" C)
  (CriarTexto "KW" 53.0 16.5 ht C)
  (CriarTexto "DEMANDA:" 63.0 16.5 ht C)
  (CriarAtt "DEMANDA" 79.0 16.5 ht "" C)
  (CriarTexto "KVA" 98.0 16.5 ht C)
  (CriarTexto "DEMANDA CONTRATADA:" 3.0 9.8 ht C)
  (CriarRetAtt "DEM_C" 42.0 8.0 57.5 12.0 "" ht C)
  (CriarTexto "KW" 58.5 9.5 ht C)
  (CriarCaixaAtt "CHK_V" 64.0  8.5 "HS-VERDE"  C ht)
  (CriarCaixaAtt "CHK_A" 85.0  8.5 "HS-AZUL"   C ht)
  (CriarCaixaAtt "CHK_B" 103.0 8.5 "OPTANTE B" C ht)
  (CriarCaixaAtt "CHK_RS" 3.0  3.5 "RAMAL SUBTERRANEO" C ht)
  (CriarCaixaAtt "CHK_RA" 43.0 3.5 "RAMAL AEREO"       C ht)
  (CriarTexto "RAMAL DE ENTRADA:" 70.0 5.2 ht C)
  (CriarRetAtt "R_ENT" 98.0 4.3 122.5 6.5 "" ht C)
  (CriarTexto "RAMAL DE LIGACAO:" 70.0 2.2 ht C)
  (CriarRetAtt "R_LIG" 98.0 0.3 122.5 3.0 "" ht C)
)

(defun GerarQ4 ( / W H C ht hos)
  (setq W 125.1945  H 33.9028  C 1  ht 2.0100  hos 3.0)
  (CriarFundoBranco W H)
  (CriarRetangulo 0 0 W H C)
  (CriarLinha 0 27.0 W 27.0 C)
  (CriarLinha 0 20.0 W 20.0 C)
  (CriarLinha 0 13.5 W 13.5 C)
  (CriarLinha 0  6.7 W  6.7 C)
  (CriarLinha 62.5 27.0 62.5 H C)
  (CriarTexto "PE" 3.0 29.0 hos C)
  (CriarAtt "PE" 9.0 29.0 hos "" C)
  (CriarTexto "OS:" 65.0 29.0 hos C)
  (CriarAtt "OS" 74.5 29.0 hos "" C)
  (CriarCaixaAtt "CHK_QC" 3.0  22.5 "QUADRO COLETIVO"    C ht)
  (CriarCaixaAtt "CHK_MI" 66.0 22.5 "MEDICAO INDIVIDUAL" C ht)
  (CriarTexto "CARGA INSTALADA:" 3.0 16.5 ht C)
  (CriarAtt "CARGA" 34.0 16.5 ht "" C)
  (CriarTexto "KW" 55.0 16.5 ht C)
  (CriarTexto "DEMANDA:" 65.0 16.5 ht C)
  (CriarAtt "DEMANDA" 79.0 16.5 ht "" C)
  (CriarTexto "KVA" 100.0 16.5 ht C)
  (CriarTexto "TRAFO EXCLUSIVO:" 3.0 10.5 ht C)
  (CriarCaixaAtt "CHK_TES" 36.0 9.5 "SIM" C ht)
  (CriarCaixaAtt "CHK_TEN" 49.0 9.5 "NAO" C ht)
  (CriarTexto "POTENCIA" 70.0 10.5 ht C)
  (CriarRetAtt "POTENCIA" 84.0 8.5 108.0 12.5 "" ht C)
  (CriarTexto "KVA" 108.5 9.5 ht C)
  (CriarRetangulo 3.0 3.8 6.015 6.815 C)
  (CriarAtt "CHK_RS" 3.3 4.1 (* ht 1.02) "" C)
  (CriarTexto "RAMAL SUBTERRANEO" 6.8 4.3 ht C)
  (CriarTexto "RS:" 42.0 4.8 ht C)
  (CriarRetAtt "RS_M" 46.5 3.8 57.0 6.8 "" ht C)
  (CriarTexto "m" 57.5 4.5 ht C)
  (CriarRetangulo 3.0 0.5 6.015 3.515 C)
  (CriarAtt "CHK_RA" 3.3 0.8 (* ht 1.02) "" C)
  (CriarTexto "RAMAL AEREO" 6.8 1.0 ht C)
  (CriarTexto "RAMAL DE ENTRADA:" 70.0 5.2 ht C)
  (CriarRetAtt "R_ENT" 98.0 4.3 122.5 6.5 "" ht C)
  (CriarTexto "RAMAL DE LIGACAO:" 70.0 2.2 ht C)
  (CriarRetAtt "R_LIG" 98.0 0.3 122.5 3.0 "" ht C)
)

(defun GerarBlocoNaMemoria (nome)
  (entmake (list
    '(0 . "BLOCK") '(100 . "AcDbEntity") '(8 . "0") '(100 . "AcDbBlockBegin")
    (cons 2 nome) '(70 . 2) '(10 0.0 0.0 0.0) (cons 3 nome) '(1 . "")
  ))
  (cond
    ((= nome "QUADRO_DESLOCAMENTO") (GerarQ1))
    ((= nome "QUADRO_LIGACAO_NOVA") (GerarQ2))
    ((= nome "QUADRO_CONEXAO")      (GerarQ3))
    ((= nome "QUADRO_MEDICAO")      (GerarQ4))
  )
  (entmake '((0 . "ENDBLK") (100 . "AcDbEntity") (8 . "0") (100 . "AcDbBlockEnd")))
)

(defun InserirBlocoComAtt (blk_name p0 vals / px py pz ename blk_rec blk_hdr ent edata new_attr item tag val ap)
  (setq px (car p0) py (cadr p0) pz (if (caddr p0) (caddr p0) 0.0))
  (entmake (list
    '(0 . "INSERT") '(100 . "AcDbEntity") '(8 . "0") '(66 . 1)
    '(100 . "AcDbBlockReference") (cons 2 blk_name) (list 10 px py pz)
    '(41 . 1.0) '(42 . 1.0) '(43 . 1.0) '(50 . 0.0)
  ))
  (setq ename (entlast))
  (setq blk_rec (tblsearch "BLOCK" blk_name) blk_hdr (cdr (assoc -2 blk_rec)) ent (entnext blk_hdr))
  (while (and ent (/= (cdr (assoc 0 (setq edata (entget ent)))) "ENDBLK"))
    (if (= (cdr (assoc 0 edata)) "ATTDEF")
      (progn
        (setq tag (cdr (assoc 2 edata)) val (cdr (assoc tag vals)))
        (if (not val) (setq val (cdr (assoc 1 edata))))
        (setq new_attr nil)
        (foreach item edata
          (cond
            ((member (car item) '(-1 5 330 3 67)))
            ((and (= (car item) 0) (= (cdr item) "ATTDEF")) (setq new_attr (cons '(0 . "ATTRIB") new_attr)))
            ((and (= (car item) 100) (= (cdr item) "AcDbAttributeDefinition")) (setq new_attr (cons '(100 . "AcDbAttribute") new_attr)))
            ((= (car item) 1) (setq new_attr (cons (cons 1 val) new_attr)))
            ((= (car item) 10) (setq ap (cdr item) new_attr (cons (list 10 (+ px (car ap)) (+ py (cadr ap)) (if (caddr ap) (+ pz (caddr ap)) pz)) new_attr)))
            ((= (car item) 11) (setq ap (cdr item) new_attr (cons (list 11 (+ px (car ap)) (+ py (cadr ap)) (if (caddr ap) (+ pz (caddr ap)) pz)) new_attr)))
            (T (setq new_attr (cons item new_attr)))
          )
        )
        (entmake (reverse new_attr))
      )
    )
    (setq ent (entnext ent))
  )
  (entmake (list '(0 . "SEQEND") '(100 . "AcDbEntity") '(8 . "0") (cons 330 ename)))
  (entupd ename)
  ename
)

;; --------------------------------------------------------------------------
;; STRINGS DE COLETA  (action_tile accept) COM STRCASE
;; --------------------------------------------------------------------------
(defun AcaoQ1 ()
  (strcat
    "(setq *DCL_VALS* (list"
    " (cons \"OS\" (strcase (get_tile \"os\")))"
    " (cons \"C_GAR\" (if (= (get_tile \"c_gar\") \"1\") \"X\" \"\"))"
    " (cons \"C_VIA\" (if (= (get_tile \"c_via\") \"1\") \"X\" \"\"))"
    " (cons \"C_EDI\" (if (= (get_tile \"c_edi\") \"1\") \"X\" \"\"))"
    " (cons \"C_TER\" (if (= (get_tile \"c_ter\") \"1\") \"X\" \"\"))"
    " (cons \"C_ISO\" (if (= (get_tile \"c_iso\") \"1\") \"X\" \"\"))"
    " (cons \"C_DAN\" (if (= (get_tile \"c_dan\") \"1\") \"X\" \"\"))"
    " (cons \"C_FOR\" (if (= (get_tile \"c_for\") \"1\") \"X\" \"\"))"
    " (cons \"C_MAD\" (if (= (get_tile \"c_mad\") \"1\") \"X\" \"\"))"
    " (cons \"D_BTA\" (strcase (get_tile \"d_bta\"))) (cons \"D_BTF\" (strcase (get_tile \"d_btf\")))"
    " (cons \"D_BMA\" (strcase (get_tile \"d_bma\"))) (cons \"D_BMF\" (strcase (get_tile \"d_bmf\")))"
    " (cons \"D_MTA\" (strcase (get_tile \"d_mta\"))) (cons \"D_MTF\" (strcase (get_tile \"d_mtf\")))"
    " (cons \"D_MMA\" (strcase (get_tile \"d_mma\"))) (cons \"D_MMF\" (strcase (get_tile \"d_mmf\")))"
    " (cons \"D_LAR\" (strcase (get_tile \"d_lar\")))"
    " (cons \"R_NEN\" (if (= (get_tile \"r_nen\") \"1\") \"X\" \"\"))"
    " (cons \"R_LEV\" (if (= (get_tile \"r_lev\") \"1\") \"X\" \"\"))"
    " (cons \"R_MED\" (if (= (get_tile \"r_med\") \"1\") \"X\" \"\"))"
    " (cons \"R_GRA\" (if (= (get_tile \"r_gra\") \"1\") \"X\" \"\"))"
    " (cons \"CX\" (strcase (get_tile \"cx\"))) (cons \"CY\" (strcase (get_tile \"cy\")))"
    " (cons \"A_SIM\" (if (= (get_tile \"a_sim\") \"1\") \"X\" \"\"))"
    " (cons \"A_NAO\" (if (= (get_tile \"a_nao\") \"1\") \"X\" \"\"))"
    " (cons \"S_SIM\" (if (= (get_tile \"s_sim\") \"1\") \"X\" \"\"))"
    " (cons \"S_NAO\" (if (= (get_tile \"s_nao\") \"1\") \"X\" \"\"))"
    " (cons \"S_OS\" (strcase (get_tile \"s_os\")))"
    " (cons \"OBS\" (strcase (get_tile \"obs\")))"
    ")) (done_dialog 1)"
  )
)
(defun AcaoQ2 ()
  (strcat
    "(setq *DCL_VALS* (list"
    " (cons \"OS\" (strcase (get_tile \"os\")))"
    " (cons \"C_LN\" (if (= (get_tile \"c_ln\") \"1\") \"X\" \"\"))"
    " (cons \"C_AC\" (if (= (get_tile \"c_ac\") \"1\") \"X\" \"\"))"
    " (cons \"RS\" (strcase (get_tile \"rs\")))"
    " (cons \"UC_EX\" (strcase (get_tile \"uc_ex\")))"
    " (cons \"C_1P\" (if (= (get_tile \"c_1p\") \"1\") \"X\" \"\"))"
    " (cons \"C_NP\" (if (= (get_tile \"c_np\") \"1\") \"X\" \"\"))"
    " (cons \"C_AG\" (if (= (get_tile \"c_ag\") \"1\") \"X\" \"\"))"
    " (cons \"CARGA\" (if (= (get_tile \"carga\") \"\") \"\" (strcat (strcase (get_tile \"carga\")) (if (= (get_tile \"opt_w\") \"1\") \" W\" \" kW\"))))"
    " (cons \"C_MO\" (if (= (get_tile \"c_mo\") \"1\") \"X\" \"\"))"
    " (cons \"C_TR\" (if (= (get_tile \"c_tr\") \"1\") \"X\" \"\"))"
    " (cons \"C_OMS\" (if (= (get_tile \"c_oms\") \"1\") \"X\" \"\"))"
    " (cons \"C_OMN\" (if (= (get_tile \"c_omn\") \"1\") \"X\" \"\"))"
    " (cons \"DISJ\" (strcase (get_tile \"disj\")))"
    " (cons \"C_RE\" (if (= (get_tile \"c_re\") \"1\") \"X\" \"\"))"
    " (cons \"C_CM\" (if (= (get_tile \"c_cm\") \"1\") \"X\" \"\"))"
    " (cons \"C_IN\" (if (= (get_tile \"c_in\") \"1\") \"X\" \"\"))"
    " (cons \"C_CO\" (if (= (get_tile \"c_co\") \"1\") \"X\" \"\"))"
    " (cons \"C_PR\" (if (= (get_tile \"c_pr\") \"1\") \"X\" \"\"))"
    " (cons \"C_IL\" (if (= (get_tile \"c_il\") \"1\") \"X\" \"\"))"
    " (cons \"C_PO\" (if (= (get_tile \"c_po\") \"1\") \"X\" \"\"))"
    " (cons \"C_IR\" (if (= (get_tile \"c_ir\") \"1\") \"X\" \"\"))"
    " (cons \"C_GE\" (if (= (get_tile \"c_ge\") \"1\") \"X\" \"\"))"
    " (cons \"MONO_CV\" (strcase (get_tile \"mono_cv\")))"
    " (cons \"TRIF_CV\" (strcase (get_tile \"trif_cv\")))"
    " (cons \"TOT_CV\" (strcase (get_tile \"tot_cv\")))"
    " (cons \"CX\" (strcase (get_tile \"cx\"))) (cons \"CY\" (strcase (get_tile \"cy\")))"
    " (cons \"OBS\" (strcase (get_tile \"obs\")))"
    " (cons \"C_TEN\" (if (= (get_tile \"c_ten\") \"1\") \"X\" \"\"))"
    " (cons \"C_TES\" (if (= (get_tile \"c_tes\") \"1\") \"X\" \"\"))"
    " (cons \"POTENCIA\" (nth (atoi (get_tile \"potencia_list\")) '(\"25 kVA\" \"30 kVA\" \"45 kVA\" \"75 kVA\" \"112,5 kVA\" \"SEM INST. TRAFO\")))"
    ")) (done_dialog 1)"
  )
)
(defun AcaoQ3 ()
  (strcat
    "(setq *DCL_VALS* (list"
    " (cons \"PE\" (strcase (get_tile \"pe\")))"
    " (cons \"OS\" (strcase (get_tile \"os\")))"
    " (cons \"CHK_TRAFO\" (if (= (get_tile \"chk_trafo\") \"1\") \"X\" \"\"))"
    " (cons \"TRAFO_KVA\" (strcase (get_tile \"trafo_kva\")))"
    " (cons \"CARGA\" (strcase (get_tile \"carga\")))"
    " (cons \"DEMANDA\" (strcase (get_tile \"demanda\")))"
    " (cons \"DEM_C\" (strcase (get_tile \"dem_c\")))"
    " (cons \"CHK_V\" (if (= (get_tile \"chk_v\") \"1\") \"X\" \"\"))"
    " (cons \"CHK_A\" (if (= (get_tile \"chk_a\") \"1\") \"X\" \"\"))"
    " (cons \"CHK_B\" (if (= (get_tile \"chk_b\") \"1\") \"X\" \"\"))"
    " (cons \"CHK_RS\" (if (= (get_tile \"chk_rs\") \"1\") \"X\" \"\"))"
    " (cons \"CHK_RA\" (if (= (get_tile \"chk_ra\") \"1\") \"X\" \"\"))"
    " (cons \"R_ENT\" (strcase (get_tile \"r_ent\")))"
    " (cons \"R_LIG\" (strcase (get_tile \"r_lig\")))"
    ")) (done_dialog 1)"
  )
)
(defun AcaoQ4 ()
  (strcat
    "(setq *DCL_VALS* (list"
    " (cons \"PE\" (strcase (get_tile \"pe\")))"
    " (cons \"OS\" (strcase (get_tile \"os\")))"
    " (cons \"CHK_QC\" (if (= (get_tile \"chk_qc\") \"1\") \"X\" \"\"))"
    " (cons \"CHK_MI\" (if (= (get_tile \"chk_mi\") \"1\") \"X\" \"\"))"
    " (cons \"CARGA\" (strcase (get_tile \"carga\")))"
    " (cons \"DEMANDA\" (strcase (get_tile \"demanda\")))"
    " (cons \"CHK_TES\" (if (= (get_tile \"chk_tes\") \"1\") \"X\" \"\"))"
    " (cons \"CHK_TEN\" (if (= (get_tile \"chk_ten\") \"1\") \"X\" \"\"))"
    " (cons \"POTENCIA\" (strcase (get_tile \"potencia\")))"
    " (cons \"CHK_RS\" (if (= (get_tile \"chk_rs\") \"1\") \"X\" \"\"))"
    " (cons \"RS_M\" (strcase (get_tile \"rs_m\")))"
    " (cons \"CHK_RA\" (if (= (get_tile \"chk_ra\") \"1\") \"X\" \"\"))"
    " (cons \"R_ENT\" (strcase (get_tile \"r_ent\")))"
    " (cons \"R_LIG\" (strcase (get_tile \"r_lig\")))"
    ")) (done_dialog 1)"
  )
)

;; --------------------------------------------------------------------------
;; DCL — SELETOR E FORMULARIOS
;; --------------------------------------------------------------------------
(defun EscreverDCL_Seletor (f)
  (foreach L (list
    "dlg_seletor : dialog { label = \"Selecione o Quadro\";"
    " : radio_column { key = \"tipo_q\";"
    "  : radio_button { key = \"q1\"; label = \"1. Deslocamento / Afastamento\"; }"
    "  : radio_button { key = \"q2\"; label = \"2. Ligacao Nova\"; }"
    "  : radio_button { key = \"q3\"; label = \"3. Conexao de Rede\"; }"
    "  : radio_button { key = \"q4\"; label = \"4. Medicao Individual e Quadro Coletivo\"; }"
    " }"
    " : row { : button { key = \"btn_alterar\"; label = \"Alterar Existente...\"; } }"
    " ok_cancel;"
    "}"
  ) (write-line L f))
)

(defun EscreverDCL_Q1 (f)
  (foreach L (list
    "dlg_form : dialog { label = \"1. Deslocamento / Afastamento\";"
    " : row { : text { label = \"\"; } : edit_box { key = \"os\"; label = \"OS:\"; width = 15; value = \"\"; } }"
    " : row {"
    "  : boxed_column { label = \"DESLOCAMENTO / AFASTAMENTO\";"
    "   : toggle { key = \"c_gar\"; label = \"Poste em frente a garagem\"; value = \"0\"; }"
    "   : toggle { key = \"c_via\"; label = \"Poste/Rede em via Publica\"; value = \"0\"; }"
    "   : toggle { key = \"c_edi\"; label = \"Poste/Rede proximo de edificacao\"; value = \"0\"; }"
    "   : toggle { key = \"c_ter\"; label = \"Poste/Rede em terreno de Terceiro\"; value = \"0\"; }"
    "  }"
    "  : boxed_column { label = \"MELHORIA DE REDE\";"
    "   : toggle { key = \"c_iso\"; label = \"Isolamento de Rede\"; value = \"0\"; }"
    "   : toggle { key = \"c_dan\"; label = \"Poste Danificado\"; value = \"0\"; }"
    "   : toggle { key = \"c_for\"; label = \"Poste Fora de Padrao\"; value = \"0\"; }"
    "   : toggle { key = \"c_mad\"; label = \"Poste de Madeira\"; value = \"0\"; }"
    "  }"
    " }"
    " : row {"
    "  : boxed_row { label = \"DISTANCIAS\";"
    "   : column {"
    "    : text { label = \"\"; } : text { label = \"BT x Parede\"; } : text { label = \"BT x Marquise/Outro\"; }"
    "    : text { label = \"MT x Parede\"; } : text { label = \"MT x Marquise/Outro\"; } : text { label = \"LARGURA DA CALCADA\"; }"
    "   }"
    "   : column {"
    "    : text { label = \"ATUAL\"; alignment = centered; } : edit_box { key = \"d_bta\"; width = 10; value = \"\"; }"
    "    : edit_box { key = \"d_bma\"; width = 10; value = \"\"; } : edit_box { key = \"d_mta\"; width = 10; value = \"\"; }"
    "    : edit_box { key = \"d_mma\"; width = 10; value = \"\"; } : edit_box { key = \"d_lar\"; width = 10; value = \"\"; }"
    "   }"
    "   : column {"
    "    : text { label = \"FUTURA\"; alignment = centered; } : edit_box { key = \"d_btf\"; width = 10; value = \"\"; }"
    "    : edit_box { key = \"d_bmf\"; width = 10; value = \"\"; } : edit_box { key = \"d_mtf\"; width = 10; value = \"\"; }"
    "    : edit_box { key = \"d_mmf\"; width = 10; value = \"\"; } : text { label = \"\"; }"
    "   }"
    "  }"
    "  : column {"
    "   : boxed_column { label = \"RISCO\";"
    "    : row { : column { : toggle { key = \"r_nen\"; label = \"NENHUM\"; value = \"0\"; } : toggle { key = \"r_med\"; label = \"MEDIO\"; value = \"0\"; } }"
    "      : column { : toggle { key = \"r_lev\"; label = \"LEVE\"; value = \"0\"; } : toggle { key = \"r_gra\"; label = \"GRAVE\"; value = \"0\"; } }"
    "    }"
    "   }"
    "   : boxed_column { label = \"COORDENADAS\";"
    "    : edit_box { key = \"cx\"; label = \"X:\"; width = 15; value = \"\"; } : edit_box { key = \"cy\"; label = \"Y:\"; width = 15; value = \"\"; }"
    "   }"
    "  }"
    " }"
    " : boxed_column { label = \"PERGUNTAS\";"
    "  : row { : text { label = \"HOUVE AVANCO POR PARTE DO SOLICITANTE?\"; } : toggle { key = \"a_sim\"; label = \"SIM\"; value = \"0\"; } : toggle { key = \"a_nao\"; label = \"NAO\"; value = \"0\"; } }"
    "  : row { : text { label = \"SIMULADO ELABORADO ANTERIORMENTE?\"; } : toggle { key = \"s_sim\"; label = \"SIM\"; value = \"0\"; } : toggle { key = \"s_nao\"; label = \"NAO\"; value = \"0\"; }"
    "   : text { label = \"  OS:\"; } : edit_box { key = \"s_os\"; width = 15; value = \"\"; } }"
    " }"
    " : boxed_row { label = \"OBSERVACOES\"; : edit_box { key = \"obs\"; width = 70; value = \"\"; } }"
    " ok_cancel;"
    "}"
  ) (write-line L f))
)

(defun EscreverDCL_Q2 (f)
  (foreach L (list
    "dlg_form : dialog { label = \"2. Ligacao Nova\";"
    " : row { : text { label = \"\"; } : edit_box { key = \"os\"; label = \"OS:\"; width = 15; value = \"\"; } }"
    " : row {"
    "  : boxed_row { label = \"FINALIDADE\"; : toggle { key = \"c_ln\"; label = \"LIGACAO NOVA\"; value = \"0\"; } : toggle { key = \"c_ac\"; label = \"AUMENTO DE CARGA\"; value = \"0\"; } }"
    "  : edit_box { key = \"rs\"; label = \"RS:\"; width = 10; value = \"\"; }"
    "  : boxed_row { label = \"UC EXISTENTE\"; : edit_box { key = \"uc_ex\"; width = 15; value = \"\"; } }"
    " }"
    " : row {"
    "  : boxed_row { label = \"QUANTIDADE DE LIGACOES\"; : toggle { key = \"c_1p\"; label = \"1 PONTO\"; value = \"0\"; } : toggle { key = \"c_np\"; label = \"NOVO PONTO\"; value = \"0\"; } : toggle { key = \"c_ag\"; label = \"AGRUPADA\"; value = \"0\"; } }"
    "  : boxed_row { label = \"CARGA INSTALADA TOTAL\"; : edit_box { key = \"carga\"; width = 10; value = \"\"; }"
    "   : radio_row { key = \"carga_unidade\"; : radio_button { key = \"opt_w\"; label = \"W\"; } : radio_button { key = \"opt_kw\"; label = \"kW\"; } }"
    "  }"
    " }"
    " : row {"
    "  : boxed_row { label = \"TIPO DE LIGACAO\"; : toggle { key = \"c_mo\"; label = \"MONOFASICA\"; value = \"0\"; } : toggle { key = \"c_tr\"; label = \"TRIFASICA\"; value = \"0\"; } }"
    "  : boxed_row { label = \"ORCAR MEDIDOR\"; : toggle { key = \"c_oms\"; label = \"SIM\"; value = \"0\"; } : toggle { key = \"c_omn\"; label = \"NAO\"; value = \"0\"; } }"
    "  : boxed_row { label = \"DISJUNTOR\"; : edit_box { key = \"disj\"; width = 10; value = \"\"; } }"
    " }"
    " : row {"
    "  : boxed_row { label = \"RAMO DA ATIVIDADE\";"
    "   : column { : toggle { key = \"c_re\"; label = \"RESIDENCIAL\"; value = \"0\"; } : toggle { key = \"c_cm\"; label = \"COMERCIAL\"; value = \"0\"; } : toggle { key = \"c_in\"; label = \"INDUSTRIAL\"; value = \"0\"; } }"
    "   : column { : toggle { key = \"c_co\"; label = \"CANT. OBRAS\"; value = \"0\"; } : toggle { key = \"c_pr\"; label = \"PROVISORIO\"; value = \"0\"; } : toggle { key = \"c_il\"; label = \"ILUM. PUBLICA\"; value = \"0\"; } }"
    "   : column { : toggle { key = \"c_po\"; label = \"POCO\"; value = \"0\"; } : toggle { key = \"c_ir\"; label = \"IRRIGAN.\"; value = \"0\"; } : toggle { key = \"c_ge\"; label = \"GERACAO\"; value = \"0\"; } }"
    "  }"
    "  : boxed_column { label = \"CV\";"
    "   : row { : text { label = \"MONOFASICA:\"; } : edit_box { key = \"mono_cv\"; width = 6; value = \"\"; } : text { label = \"CV\"; } }"
    "   : row { : text { label = \"TRIFASICA:\"; } : edit_box { key = \"trif_cv\"; width = 6; value = \"\"; } : text { label = \"CV\"; } }"
    "   : row { : text { label = \"TOTAL:\"; } : edit_box { key = \"tot_cv\"; width = 6; value = \"\"; } : text { label = \"CV\"; } }"
    "  }"
    " }"
    " : row { : boxed_row { label = \"COORDENADAS\"; : edit_box { key = \"cx\"; label = \"X:\"; width = 15; value = \"\"; } : edit_box { key = \"cy\"; label = \"Y:\"; width = 15; value = \"\"; } } }"
    " : boxed_row { label = \"OBSERVACOES\"; : edit_box { key = \"obs\"; width = 70; value = \"\"; } }"
    " : row {"
    "  : boxed_row { label = \"TRAFO EXCLUSIVO\"; : toggle { key = \"c_ten\"; label = \"NAO\"; value = \"0\"; } : toggle { key = \"c_tes\"; label = \"SIM\"; value = \"0\"; } }"
    "  : boxed_row { label = \"POTENCIA\"; : popup_list { key = \"potencia_list\"; width = 20; } }"
    " }"
    " ok_cancel;"
    "}"
  ) (write-line L f))
)

(defun EscreverDCL_Q3 (f)
  (foreach L (list
    "dlg_form : dialog { label = \"3. Conexao de Rede\";"
    " : row { : edit_box { key = \"pe\"; label = \"PE\"; width = 10; value = \"\"; } : text { label = \"\"; } : edit_box { key = \"os\"; label = \"OS:\"; width = 15; value = \"\"; } }"
    " : row { : boxed_row { label = \"TRAFO PARTICULAR\"; : toggle { key = \"chk_trafo\"; label = \"TRAFO PARTICULAR\"; value = \"0\"; } : edit_box { key = \"trafo_kva\"; width = 8; value = \"\"; } : text { label = \"KVA\"; } } }"
    " : row {"
    "  : boxed_row { label = \"CARGA INSTALADA\"; : edit_box { key = \"carga\"; width = 10; value = \"\"; } : text { label = \"KW\"; } }"
    "  : boxed_row { label = \"DEMANDA\"; : edit_box { key = \"demanda\"; width = 10; value = \"\"; } : text { label = \"KVA\"; } }"
    " }"
    " : row {"
    "  : boxed_row { label = \"DEMANDA CONTRATADA\"; : edit_box { key = \"dem_c\"; width = 10; value = \"\"; } : text { label = \"KW\"; } }"
    "  : boxed_row { label = \"TIPO\"; : toggle { key = \"chk_v\"; label = \"HS-VERDE\"; value = \"0\"; } : toggle { key = \"chk_a\"; label = \"HS-AZUL\"; value = \"0\"; } : toggle { key = \"chk_b\"; label = \"OPTANTE B\"; value = \"0\"; } }"
    " }"
    " : row {"
    "  : boxed_column { label = \"RAMAL\"; : toggle { key = \"chk_rs\"; label = \"RAMAL SUBTERRANEO\"; value = \"0\"; } : toggle { key = \"chk_ra\"; label = \"RAMAL AEREO\"; value = \"0\"; } }"
    "  : column { : edit_box { key = \"r_ent\"; label = \"RAMAL DE ENTRADA:\"; width = 20; value = \"\"; } : edit_box { key = \"r_lig\"; label = \"RAMAL DE LIGACAO:\"; width = 20; value = \"\"; } }"
    " }"
    " ok_cancel;"
    "}"
  ) (write-line L f))
)

(defun EscreverDCL_Q4 (f)
  (foreach L (list
    "dlg_form : dialog { label = \"4. Medicao Individual e Quadro Coletivo\";"
    " : row { : edit_box { key = \"pe\"; label = \"PE\"; width = 10; value = \"\"; } : text { label = \"\"; } : edit_box { key = \"os\"; label = \"OS:\"; width = 15; value = \"\"; } }"
    " : row { : boxed_row { label = \"TIPO DE MEDICAO\"; : toggle { key = \"chk_qc\"; label = \"QUADRO COLETIVO\"; value = \"0\"; } : toggle { key = \"chk_mi\"; label = \"MEDICAO INDIVIDUAL\"; value = \"0\"; } } }"
    " : row {"
    "  : boxed_row { label = \"CARGA INSTALADA\"; : edit_box { key = \"carga\"; width = 10; value = \"\"; } : text { label = \"KW\"; } }"
    "  : boxed_row { label = \"DEMANDA\"; : edit_box { key = \"demanda\"; width = 10; value = \"\"; } : text { label = \"KVA\"; } }"
    " }"
    " : row {"
    "  : boxed_row { label = \"TRAFO EXCLUSIVO\"; : toggle { key = \"chk_tes\"; label = \"SIM\"; value = \"0\"; } : toggle { key = \"chk_ten\"; label = \"NAO\"; value = \"0\"; } }"
    "  : boxed_row { label = \"POTENCIA\"; : edit_box { key = \"potencia\"; width = 10; value = \"\"; } : text { label = \"KVA\"; } }"
    " }"
    " : row {"
    "  : boxed_column { label = \"RAMAL\";"
    "   : row { : toggle { key = \"chk_rs\"; label = \"RAMAL SUBTERRANEO\"; value = \"0\"; } : text { label = \"RS:\"; } : edit_box { key = \"rs_m\"; width = 6; value = \"\"; } : text { label = \"m\"; } }"
    "   : toggle { key = \"chk_ra\"; label = \"RAMAL AEREO\"; value = \"0\"; }"
    "  }"
    "  : column { : edit_box { key = \"r_ent\"; label = \"RAMAL DE ENTRADA:\"; width = 20; value = \"\"; } : edit_box { key = \"r_lig\"; label = \"RAMAL DE LIGACAO:\"; width = 20; value = \"\"; } }"
    " }"
    " ok_cancel;"
    "}"
  ) (write-line L f))
)

;; --------------------------------------------------------------------------
;; COMANDO PRINCIPAL
;; --------------------------------------------------------------------------
(defun c:QUADRO ( / dcl_id dcl_file f result p0
                    blk_name ent_prev ent attr attrdata tag val
                    old_req old_dia accept_str sel_ent bname atts edit_ent carga_str pot_str pot_idx)
  (setvar "CMDECHO" 0)
  (setq old_req (getvar "ATTREQ") old_dia (getvar "ATTDIA"))
  (setvar "ATTREQ" 0)
  (setvar "ATTDIA" 0)

  ;; ETAPA 1 — SELETOR
  (setq dcl_file (QuadroTmpFile "quadro_seletor"))
  (setq f (open dcl_file "w"))
  (EscreverDCL_Seletor f)
  (close f)
  (setq dcl_id (load_dialog dcl_file))
  (if (< dcl_id 0)
    (progn (alert "Erro ao carregar dialogo seletor!") (setvar "ATTREQ" old_req) (setvar "ATTDIA" old_dia) (princ) (exit))
  )
  (new_dialog "dlg_seletor" dcl_id)
  (set_tile "tipo_q" *Q_ESCOLHA*)
  (action_tile "q1" "(setq *Q_ESCOLHA* \"q1\")")
  (action_tile "q2" "(setq *Q_ESCOLHA* \"q2\")")
  (action_tile "q3" "(setq *Q_ESCOLHA* \"q3\")")
  (action_tile "q4" "(setq *Q_ESCOLHA* \"q4\")")
  (action_tile "btn_alterar" "(done_dialog 2)")
  (action_tile "accept" "(done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)")
  (setq result (start_dialog))
  (unload_dialog dcl_id)
  (vl-file-delete dcl_file)

  (if (= result 0) (progn (setvar "ATTREQ" old_req) (setvar "ATTDIA" old_dia) (princ) (exit)))

  ;; VERIFICACAO: SE O USUARIO ESCOLHEU ALTERAR EXISTENTE
  (setq edit_ent nil atts nil)
  (if (= result 2)
    (progn
      (setq sel_ent (car (entsel "\nSelecione o quadro existente para alterar: ")))
      (if (and sel_ent (= (cdr (assoc 0 (entget sel_ent))) "INSERT"))
        (progn
          (setq bname (cdr (assoc 2 (entget sel_ent))))
          (cond
            ((= bname "QUADRO_DESLOCAMENTO") (setq *Q_ESCOLHA* "q1"))
            ((= bname "QUADRO_LIGACAO_NOVA") (setq *Q_ESCOLHA* "q2"))
            ((= bname "QUADRO_CONEXAO")      (setq *Q_ESCOLHA* "q3"))
            ((= bname "QUADRO_MEDICAO")      (setq *Q_ESCOLHA* "q4"))
            (T (alert "Bloco selecionado nao e um Quadro compativel.") (setvar "ATTREQ" old_req) (setvar "ATTDIA" old_dia) (exit))
          )
          (setq edit_ent sel_ent)
          (setq atts (ObterAtributosBloco sel_ent))
        )
        (progn
          (alert "Nenhum bloco valido selecionado!")
          (setvar "ATTREQ" old_req) (setvar "ATTDIA" old_dia) (exit)
        )
      )
    )
  )

  ;; ETAPA 2 — FORMULARIO
  (setq dcl_file (QuadroTmpFile "quadro_form"))
  (setq f (open dcl_file "w"))
  (cond
    ((= *Q_ESCOLHA* "q1") (EscreverDCL_Q1 f))
    ((= *Q_ESCOLHA* "q2") (EscreverDCL_Q2 f))
    ((= *Q_ESCOLHA* "q3") (EscreverDCL_Q3 f))
    ((= *Q_ESCOLHA* "q4") (EscreverDCL_Q4 f))
  )
  (close f)
  (setq dcl_id (load_dialog dcl_file))
  (if (< dcl_id 0)
    (progn (alert "Erro ao carregar dialogo de formulario!") (setvar "ATTREQ" old_req) (setvar "ATTDIA" old_dia) (princ) (exit))
  )
  (new_dialog "dlg_form" dcl_id)
  
  ;; DEFAULTS E PREENCHIMENTO INTELIGENTE VIA DCL
  (cond
    ((= *Q_ESCOLHA* "q1")
     (foreach k '("c_gar" "c_via" "c_edi" "c_ter" "c_iso" "c_dan" "c_for" "c_mad"
                  "r_nen" "r_lev" "r_med" "r_gra" "a_sim" "a_nao" "s_sim" "s_nao")
       (InitDclTile k (strcase k) "0" T atts))
     (foreach k '("os" "d_bta" "d_btf" "d_bma" "d_bmf" "d_mta" "d_mtf"
                  "d_mma" "d_mmf" "d_lar" "cx" "cy" "s_os" "obs")
       (InitDclTile k (strcase k) "" nil atts))
     (if (not atts)
       (progn
         (set_tile "os"    "XXXXXXXX")
         (set_tile "d_mta" "SOBRE")
         (set_tile "d_mtf" "2.10m")
         (set_tile "obs"   "DATA DO POSTE:")
         (set_tile "c_edi" "1")
         (set_tile "r_nen" "1")
         (set_tile "a_sim" "1")
         (set_tile "s_nao" "1")
       )
     )
    )
    ((= *Q_ESCOLHA* "q2")
     (foreach k '("c_ln" "c_ac" "c_1p" "c_np" "c_ag" "c_mo" "c_tr"
                  "c_oms" "c_omn" "c_re" "c_cm" "c_in" "c_co" "c_pr"
                  "c_il" "c_po" "c_ir" "c_ge" "c_ten" "c_tes")
       (InitDclTile k (strcase k) "0" T atts))
     (foreach k '("os" "rs" "uc_ex" "disj" "mono_cv" "trif_cv"
                  "tot_cv" "cx" "cy" "obs")
       (InitDclTile k (strcase k) "" nil atts))

     (start_list "potencia_list")
     (mapcar 'add_list '("25 kVA" "30 kVA" "45 kVA" "75 kVA" "112,5 kVA" "SEM INST. TRAFO"))
     (end_list)

     (if atts
       (progn
         (setq carga_str (cdr (assoc "CARGA" atts)))
         (if (not carga_str) (setq carga_str ""))
         (cond
           ((vl-string-search " kW" carga_str)
            (set_tile "carga" (vl-string-subst "" " kW" carga_str))
            (set_tile "opt_kw" "1"))
           ((vl-string-search " W" carga_str)
            (set_tile "carga" (vl-string-subst "" " W" carga_str))
            (set_tile "opt_w" "1"))
           (T
            (set_tile "carga" carga_str)
            (set_tile "opt_kw" "1"))
         )
         (setq pot_str (cdr (assoc "POTENCIA" atts)))
         (setq pot_idx (vl-position pot_str '("25 kVA" "30 kVA" "45 kVA" "75 kVA" "112,5 kVA" "SEM INST. TRAFO")))
         (if pot_idx (set_tile "potencia_list" (itoa pot_idx)) (set_tile "potencia_list" "0"))
       )
       (progn
         (set_tile "carga" "")
         (set_tile "potencia_list" "0")
         (set_tile "opt_w" "1")
         (set_tile "os"    "XXXXXXXX")
         (set_tile "disj"  "32")
         (set_tile "c_ln"  "1")
         (set_tile "c_1p"  "1")
         (set_tile "c_mo"  "1")
         (set_tile "c_oms" "1")
         (set_tile "c_re"  "1")
       )
     )
    )
    ((= *Q_ESCOLHA* "q3")
     (foreach k '("chk_trafo" "chk_v" "chk_a" "chk_b" "chk_rs" "chk_ra")
       (InitDclTile k (strcase k) "0" T atts))
     (foreach k '("pe" "os" "trafo_kva" "carga" "demanda" "dem_c" "r_ent" "r_lig")
       (InitDclTile k (strcase k) "" nil atts))
     (if (not atts)
       (progn
         (set_tile "pe"        "XXXX/XX")
         (set_tile "os"        "XXXXXXXX")
         (set_tile "chk_trafo" "1")
         (set_tile "chk_ra"    "1")
         (set_tile "chk_b"     "1")
       )
     )
    )
    ((= *Q_ESCOLHA* "q4")
     (foreach k '("chk_qc" "chk_mi" "chk_tes" "chk_ten" "chk_rs" "chk_ra")
       (InitDclTile k (strcase k) "0" T atts))
     (foreach k '("pe" "os" "carga" "demanda" "potencia" "rs_m" "r_ent" "r_lig")
       (InitDclTile k (strcase k) "" nil atts))
     (if (not atts)
       (progn
         (set_tile "pe"      "XXXX/XX")
         (set_tile "os"      "XXXXXXXX")
         (set_tile "chk_qc"  "1")
         (set_tile "chk_tes" "1")
         (set_tile "chk_ra"  "1")
         (set_tile "r_ent"   "Mx1x10+10")
       )
     )
    )
  )
  
  (setq accept_str
    (cond
      ((= *Q_ESCOLHA* "q1") (AcaoQ1))
      ((= *Q_ESCOLHA* "q2") (AcaoQ2))
      ((= *Q_ESCOLHA* "q3") (AcaoQ3))
      (T                    (AcaoQ4))
    )
  )
  (action_tile "accept" accept_str)
  (action_tile "cancel" "(done_dialog 0)")
  (setq result (start_dialog))
  (unload_dialog dcl_id)
  (vl-file-delete dcl_file)

  ;; ETAPA 3 — GERAR BLOCO/INSERIR OU ATUALIZAR EXISTENTE
  (if (= result 1)
    (if edit_ent
      (progn
        ;; Atualiza o bloco existente selecionado
        (AtualizarAtributosBloco edit_ent *DCL_VALS*)
        (princ "\nQuadro atualizado com sucesso!")
      )
      (progn
        ;; Cria e insere um novo bloco
        (setq blk_name
          (cond
            ((= *Q_ESCOLHA* "q1") "QUADRO_DESLOCAMENTO")
            ((= *Q_ESCOLHA* "q2") "QUADRO_LIGACAO_NOVA")
            ((= *Q_ESCOLHA* "q3") "QUADRO_CONEXAO")
            ((= *Q_ESCOLHA* "q4") "QUADRO_MEDICAO")
          )
        )
        (if (not (tblsearch "BLOCK" blk_name))
          (GerarBlocoNaMemoria blk_name)
        )
        (if (not (tblsearch "BLOCK" blk_name))
          (progn
            (alert (strcat "Erro: nao foi possivel criar o bloco " blk_name))
            (setvar "ATTREQ" old_req) (setvar "ATTDIA" old_dia) (princ) (exit)
          )
        )
        (setq p0 (getpoint (strcat "\nClique o ponto de insercao [" blk_name "]: ")))
        (if p0
          (progn
            (InserirBlocoComAtt blk_name p0 *DCL_VALS*)
            (princ "\nNovo Quadro inserido com sucesso!")
          )
          (princ "\nInsercao cancelada.")
        )
      )
    )
  )
  (setvar "ATTREQ" old_req)
  (setvar "ATTDIA" old_dia)
  (princ)
)

(princ "\n>> QUADRO carregado. Digite QUADRO para iniciar.")
(princ)