Excelente escolha. A **Opção 1** é, de longe, a mais estável e fluida para o motor padrão do AutoLISP, pois você aproveita 100% da aceleração de hardware e do rastreamento visual (rubber-band, Osnaps, Ortho) nativos do CAD, sem interrupções.

Aqui está o código completo, limpo e enxuto.

**Como vai funcionar na prática (Escala 1:500):**

1. O comando pede o próximo ponto.
2. Você aponta o mouse para a direção desejada.
3. Digita **o tamanho que a linha deve ter na tela** (ex: `20`) e dá *Enter*.
4. O CAD desenha a linha instantaneamente com 20 de comprimento, e o LISP faz a conta automática para a anotação, escrevendo **10 m**. Tudo em um clique/movimento contínuo.

Segue o código pronto para uso:

```lisp
;; CABO.lsp - Compativel com nanoCAD 5 gratuito (e AutoCAD)
;; DCL gerado dinamicamente em arquivo temporario e excluido apos o uso
;;
;; LOGICA DE ENTRADA (Opcao 1 - Matemática Direta no Canvas):
;; O usuario aponta e digita (ou clica) a distancia real que a linha deve ter no desenho.
;; A LISP desenha a linha exata e calcula a anotação dividindo pela escala.
;; Exemplo 1:500 - Aponta, digita "20", linha fica com 20, texto anota "10 m".

(defun c:CABO (/ desc rede fase opc tipo cor ltype p1 p2 dist distTxt txt
                 ang_orig ang midPt off txtPt txtH pad pad_risco
                 pA pB pC pD pR1 pR2 C_i
                 idx char cur_len max_len num_linhas lines_len
                 char_w line_sp total_h total_w dx_left dx_right
                 i top_offset w_i y_offset_i
                 dcl_id dlg_result dcl_file f_dcl
                 v_rede v_fase v_opc_MT v_opc_BT v_desc_livre v_tipo
                 v_escala_fator escala_fator)

  (vl-load-com)

  ;;; ============================================================
  ;;; CONFIGURACOES VISUAIS
  ;;; ============================================================
  (setq txtH      1.5
        pad       0.40
        pad_risco 0.15
        char_w    (* 1.5 0.72)
        line_sp   (* 1.5 1.6))

  ;;; ============================================================
  ;;; CRIAR DCL TEMPORARIO
  ;;; ============================================================
  (setq dcl_file (vl-filename-mktemp "CABO.dcl"))
  (setq f_dcl (open dcl_file "w"))
  (foreach line
    '(
      "cabo_dlg : dialog {"
      "  label = \"Cabo - Configuracao\";"
      "  width = 54;"
      "  : text { label = \"--- REDE E FASE ---\"; width = 50; }"
      "  : row {"
      "    : text { label = \"Rede:\"; width = 22; }"
      "    : radio_button { key = \"rede_MT\"; label = \"MT\"; }"
      "    : radio_button { key = \"rede_BT\"; label = \"BT\"; }"
      "  }"
      "  : row {"
      "    : text { label = \"Fase:\"; width = 22; }"
      "    : radio_button { key = \"fase_ABC\"; label = \"ABC\"; }"
      "    : radio_button { key = \"fase_AC\";  label = \"AC\"; }"
      "    : radio_button { key = \"fase_A\";   label = \"A\"; }"
      "    : radio_button { key = \"fase_B\";   label = \"B\"; }"
      "    : radio_button { key = \"fase_C\";   label = \"C\"; }"
      "  }"
      "  : spacer { height = 1; }"
      "  : text { label = \"--- ESCALA ---\"; width = 50; }"
      "  : row {"
      "    : text { label = \"Escala:\"; width = 22; }"
      "    : radio_button { key = \"escala_1000\"; label = \"1:1000\"; }"
      "    : radio_button { key = \"escala_500\";  label = \"1:500\"; }"
      "  }"
      "  : spacer { height = 1; }"
      "  : text { label = \"--- DESCRICAO DO CABO ---\"; width = 50; }"
      "  : row {"
      "    : text { label = \"Cabo (MT):\"; width = 22; }"
      "    : popup_list { key = \"opc_MT\"; width = 24; }"
      "  }"
      "  : row {"
      "    : text { label = \"Cabo (BT):\"; width = 22; }"
      "    : popup_list { key = \"opc_BT\"; width = 28; }"
      "  }"
      "  : row {"
      "    : text { label = \"Descricao livre:\"; width = 22; }"
      "    : edit_box { key = \"desc_livre\"; width = 24; }"
      "  }"
      "  : spacer { height = 1; }"
      "  : text { label = \"--- OPERACAO ---\"; width = 50; }"
      "  : row {"
      "    : text { label = \"Operacao:\"; width = 22; }"
      "    : radio_button { key = \"tipo_I\"; label = \"Instalando\"; }"
      "    : radio_button { key = \"tipo_R\"; label = \"Removendo\"; }"
      "  }"
      "  : spacer { height = 1; }"
      "  : row {"
      "    : button { key = \"accept\"; label = \"OK\";       is_default = true; width = 12; }"
      "    : button { key = \"cancel\"; label = \"Cancelar\"; is_cancel  = true; width = 12; }"
      "  }"
      "}"
    )
    (write-line line f_dcl)
  )
  (close f_dcl)

  ;;; ============================================================
  ;;; LISTAS
  ;;; ============================================================
  (setq mt_list (list "CAA 2" "CAA 4" "CAA 1/0" "CAA 4/0" "CAA 336,4"
                      "P 50 / CAZ 9,5" "P 120 / CAZ 9,5" "P 185 / CAZ 9,5" "Outro"))
  (setq mt_desc (list "CAA 2" "CAA 4" "CAA 1/0" "CAA 4/0" "CAA 336,4"
                      "P 50\\pCAZ 9,5" "P 120\\pCAZ 9,5" "P 185\\pCAZ 9,5" nil))
  (setq bt_list (list "M2x1x35+35" "M3x1x35+35" "M3x1x35+35 NI" "M3x1x70+70" "M3x1x70+70 NI"
                      "M3x1x120+70" "M3x1x120+70 NI" "CA 4" "CA 1/0 / CA 4" "Outro"))
  (setq bt_desc (list "M2x1x35+35" "M3x1x35+35" "M3x1x35+35 NI" "M3x1x70+70" "M3x1x70+70 NI"
                      "M3x1x120+70" "M3x1x120+70 NI" "CA 4" "CA 1/0\\pCA 4" nil))

  ;;; ============================================================
  ;;; ABRIR DIALOGO
  ;;; ============================================================
  (setq dcl_id (load_dialog dcl_file))
  (if (< dcl_id 0) 
    (progn (alert "Erro ao carregar CABO.dcl temporário.") (vl-file-delete dcl_file) (exit)))
  
  (if (not (new_dialog "cabo_dlg" dcl_id))
    (progn (alert "Erro ao abrir cabo_dlg.") (unload_dialog dcl_id) (vl-file-delete dcl_file) (exit)))

  (start_list "opc_MT") (foreach v mt_list (add_list v)) (end_list)
  (start_list "opc_BT") (foreach v bt_list (add_list v)) (end_list)

  ;; Valores Iniciais
  (set_tile "rede_MT"  "1") (set_tile "rede_BT"  "0")
  (set_tile "fase_ABC" "1") (set_tile "fase_AC"  "0") (set_tile "fase_A" "0") (set_tile "fase_B" "0") (set_tile "fase_C" "0")
  (set_tile "escala_1000" "1") (set_tile "escala_500"  "0")
  (set_tile "tipo_I"   "1") (set_tile "tipo_R"   "0")
  (mode_tile "opc_MT"     0) (mode_tile "opc_BT"     1) (mode_tile "desc_livre" 1)

  ;; Callbacks
  (action_tile "rede_MT" "(set_tile \"rede_MT\" \"1\") (set_tile \"rede_BT\" \"0\") (mode_tile \"opc_MT\" 0) (mode_tile \"opc_BT\" 1) (mode_tile \"desc_livre\" 1)")
  (action_tile "rede_BT" "(set_tile \"rede_MT\" \"0\") (set_tile \"rede_BT\" \"1\") (mode_tile \"opc_BT\" 0) (mode_tile \"opc_MT\" 1) (mode_tile \"desc_livre\" 1)")
  (action_tile "fase_ABC" "(set_tile \"fase_ABC\" \"1\") (set_tile \"fase_AC\" \"0\") (set_tile \"fase_A\" \"0\") (set_tile \"fase_B\" \"0\") (set_tile \"fase_C\" \"0\")")
  (action_tile "fase_AC" "(set_tile \"fase_ABC\" \"0\") (set_tile \"fase_AC\" \"1\") (set_tile \"fase_A\" \"0\") (set_tile \"fase_B\" \"0\") (set_tile \"fase_C\" \"0\")")
  (action_tile "fase_A" "(set_tile \"fase_ABC\" \"0\") (set_tile \"fase_AC\" \"0\") (set_tile \"fase_A\" \"1\") (set_tile \"fase_B\" \"0\") (set_tile \"fase_C\" \"0\")")
  (action_tile "fase_B" "(set_tile \"fase_ABC\" \"0\") (set_tile \"fase_AC\" \"0\") (set_tile \"fase_A\" \"0\") (set_tile \"fase_B\" \"1\") (set_tile \"fase_C\" \"0\")")
  (action_tile "fase_C" "(set_tile \"fase_ABC\" \"0\") (set_tile \"fase_AC\" \"0\") (set_tile \"fase_A\" \"0\") (set_tile \"fase_B\" \"0\") (set_tile \"fase_C\" \"1\")")
  (action_tile "escala_1000" "(set_tile \"escala_1000\" \"1\") (set_tile \"escala_500\" \"0\")")
  (action_tile "escala_500" "(set_tile \"escala_1000\" \"0\") (set_tile \"escala_500\" \"1\")")
  (action_tile "tipo_I" "(set_tile \"tipo_I\" \"1\") (set_tile \"tipo_R\" \"0\")")
  (action_tile "tipo_R" "(set_tile \"tipo_I\" \"0\") (set_tile \"tipo_R\" \"1\")")
  (action_tile "opc_MT" "(setq v_opc_MT (atoi $value)) (if (= v_opc_MT 8) (mode_tile \"desc_livre\" 0) (mode_tile \"desc_livre\" 1))")
  (action_tile "opc_BT" "(setq v_opc_BT (atoi $value)) (if (= v_opc_BT 9) (mode_tile \"desc_livre\" 0) (mode_tile \"desc_livre\" 1))")
  
  (action_tile "accept"
    "(setq v_rede       (if (= (get_tile \"rede_MT\") \"1\") \"MT\" \"BT\")
           v_fase       (cond ((= (get_tile \"fase_ABC\") \"1\") \"ABC\")
                              ((= (get_tile \"fase_AC\")  \"1\") \"AC\")
                              ((= (get_tile \"fase_A\")   \"1\") \"A\")
                              ((= (get_tile \"fase_B\")   \"1\") \"B\")
                              (T \"C\"))
           v_opc_MT     (atoi (get_tile \"opc_MT\"))
           v_opc_BT     (atoi (get_tile \"opc_BT\"))
           v_desc_livre (get_tile \"desc_livre\")
           v_tipo       (if (= (get_tile \"tipo_I\") \"1\") \"I\" \"R\")
           v_escala_fator (if (= (get_tile \"escala_500\") \"1\") 2.0 1.0))
     (done_dialog 1)")

  (setq dlg_result (start_dialog))
  (unload_dialog dcl_id)
  (vl-file-delete dcl_file)

  (if (/= dlg_result 1) (progn (princ "\nCancelado.") (princ) (exit)))

  ;;; ============================================================
  ;;; POS-DIALOGO (Carrega Variáveis)
  ;;; ============================================================
  (setq rede v_rede
        fase v_fase
        tipo v_tipo
        escala_fator v_escala_fator)
        
  (if (= rede "MT")
    (setq desc (if (= v_opc_MT 8) v_desc_livre (nth v_opc_MT mt_desc)))
    (setq desc (if (= v_opc_BT 9) v_desc_livre (nth v_opc_BT bt_desc))))
  (if (not desc) (setq desc ""))

  (setq cor   (if (= tipo "I") 1 8)
        ltype "Continuous")
  (if (= rede "MT")
    (cond ((tblsearch "ltype" "TRACEJADA") (setq ltype "TRACEJADA"))
          ((tblsearch "ltype" "DASHED")    (setq ltype "DASHED"))
          ((tblsearch "ltype" "HIDDEN")    (setq ltype "HIDDEN"))))

  ;;; ============================================================
  ;;; LOOP DE DESENHO CONTÍNUO (Opção 1)
  ;;; ============================================================
  (setq p1 (getpoint "\nClique no ponto inicial: "))
  
  ;; O getpoint padrão pega perfeitamente cliques e digitações com o rubber-band visual
  (while (setq p2 (getpoint p1 "\nProximo ponto ou digite a distancia final no desenho (ENTER para sair): "))
    
    ;; Pega a distância real desenhada no canvas e divide pela escala para gerar a anotação
    (setq dist    (fix (+ (/ (distance p1 p2) escala_fator) 0.5))
          distTxt (itoa dist)
          txt     (strcat " " desc " " fase " " distTxt " m "))
          
    (while (vl-string-search "\\p" txt)
      (setq txt (vl-string-subst " \\P " "\\p" txt)))
      
    (setq ang_orig (angle p1 p2)
          ang      ang_orig)
          
    ;; Cria a linha
    (entmake (list '(0 . "LINE") (cons 10 p1) (cons 11 p2) (cons 62 cor) (cons 6 ltype)))
    
    (if (and (> ang_orig (/ pi 2)) (<= ang_orig (* pi 1.5)))
      (setq ang (- ang pi)))
      
    ;; Processamento de quebra de texto
    (setq max_len 0 cur_len 0 idx 1 lines_len '())
    (while (<= idx (strlen txt))
      (setq char (substr txt idx 2))
      (if (= char "\\P")
        (progn
          (setq lines_len (append lines_len (list cur_len)))
          (if (> cur_len max_len) (setq max_len cur_len))
          (setq cur_len 0 idx (+ idx 2)))
        (progn (setq cur_len (1+ cur_len) idx (1+ idx)))))
    (setq lines_len (append lines_len (list cur_len)))
    (if (> cur_len max_len) (setq max_len cur_len))
    
    (setq num_linhas (length lines_len)
          total_h    (+ txtH (* (1- num_linhas) line_sp))
          total_w    (* max_len char_w))
          
    ;; Posicionamento do Texto
    (setq midPt (mapcar '(lambda (a b) (/ (+ a b) 2.0)) p1 p2)
          off   (+ 1.0 (/ total_h 2.0)))
    (if (and (> ang_orig (/ pi 2)) (<= ang_orig (* pi 1.5)))
      (setq txtPt (polar midPt (- ang (/ pi 2)) off))
      (setq txtPt (polar midPt (+ ang (/ pi 2)) off)))
      
    ;; Cria o MTEXT
    (entmake (list '(0 . "MTEXT") '(100 . "AcDbEntity") '(100 . "AcDbMText")
                   (cons 10 txtPt) (cons 40 txtH) (cons 41 0.0) (cons 71 5)
                   (cons 1 txt) (cons 50 ang) (cons 62 cor)))
                   
    ;; Cria os complementos (Instalando = Caixa / Removendo = Riscos)
    (if (= tipo "I")
      (progn
        (setq dx_left  (polar txtPt (+ ang pi) (+ (/ total_w 2.0) pad))
              dx_right (polar txtPt ang         (+ (/ total_w 2.0) pad))
              pA       (polar dx_left  (- ang (/ pi 2)) (+ (/ total_h 2.0) pad))
              pB       (polar dx_right (- ang (/ pi 2)) (+ (/ total_h 2.0) pad))
              pC       (polar dx_right (+ ang (/ pi 2)) (+ (/ total_h 2.0) pad))
              pD       (polar dx_left  (+ ang (/ pi 2)) (+ (/ total_h 2.0) pad)))
        (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
                       '(90 . 4) '(70 . 1) (cons 62 cor)
                       (cons 10 pA) (cons 10 pB) (cons 10 pC) (cons 10 pD)))))
                       
    (if (= tipo "R")
      (progn
        (setq i 0 top_offset (/ (* (1- num_linhas) line_sp) 2.0))
        (while (< i num_linhas)
          (setq w_i        (* (nth i lines_len) char_w)
                y_offset_i (- top_offset (* i line_sp))
                C_i        (polar txtPt (+ ang (/ pi 2)) y_offset_i)
                pR1        (polar C_i (+ ang pi) (+ (/ w_i 2.0) pad_risco))
                pR2        (polar C_i ang         (+ (/ w_i 2.0) pad_risco)))
          (entmake (list '(0 . "LINE") (cons 10 pR1) (cons 11 pR2) (cons 62 cor)))
          (setq i (1+ i)))))
          
    ;; Avança o ponto base para o próximo trecho
    (setq p1 p2)
  )
  
  (princ "\nComando CABO concluido.")
  (princ)
)

```