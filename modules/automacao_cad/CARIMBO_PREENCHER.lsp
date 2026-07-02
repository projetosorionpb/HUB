;;; ============================================================
;;; CARIMBO_PREENCHER.LSP  (v15.2)
;;; NanoCAD 5 / AutoCAD - AutoLISP classico
;;; ============================================================
;;; CHANGELOG v15.2:
;;;   [MEM] Historico dos campos Objetivo, Servico, Levantamento,
;;;         Desenho e Orcamento agora salvo em pasta GLOBAL:
;;;         AppData\Local\NanoCAD_Scripts_CAD\carimbo_memoria.ini
;;;         A pasta e o arquivo sao criados automaticamente se nao
;;;         existirem. O historico permanece disponivel ao mudar
;;;         de pasta ou projeto.
;;; CHANGELOG v15.1:
;;;   [UI] Reorganizacao visual do DCL: 
;;;        - Campo Servico movido para baixo de Obra N.
;;;        - Responsaveis reordenados: Levantamento, Desenho, Orcamento
;;;   [UI/MEM] Implementado historico interativo (tipo ComboBox)
;;;            para: Objetivo, Servico, Orcamento, Levantamento e
;;;            Desenho. Os botoes "Salvar" gravam o item numa lista.
;;;            As listas suspensas (dropdown) ao lado dos campos
;;;            permitem clicar e autopreencher com itens salvos.
;;;            O botao Limpar agora esvazia esses campos.
;;; ============================================================

;;; ============================================================
;;; FUNCOES DE STRING E LISTA
;;; ============================================================

(defun str-replace (velho novo str / len_v res p)
  (setq len_v (strlen velho))
  (setq res "")
  (if (and (> len_v 0) str)
    (progn
      (while (setq p (vl-string-search velho str))
        (setq res (strcat res (substr str 1 p) novo))
        (setq str (substr str (+ p 1 len_v)))
      )
      (setq str (strcat res str))
    )
  )
  str
)

(defun str-split (str delim / p res len_d)
  (setq len_d (strlen delim))
  (setq res nil)
  (if (> len_d 0)
    (progn
      (while (setq p (vl-string-search delim str))
        (setq res (cons (substr str 1 p) res))
        (setq str (substr str (+ p 1 len_d)))
      )
      (setq res (reverse (cons str res)))
    )
    (setq res (list str))
  )
  res
)

(defun str-join (lista delim / res)
  (setq res "")
  (if lista
    (progn
      (setq res (car lista))
      (foreach item (cdr lista)
        (setq res (strcat res delim item))
      )
    )
  )
  res
)

(defun remove-item-lista (item lista / res)
  (setq res nil)
  (foreach x lista
    (if (/= x item) (setq res (cons x res)))
  )
  (reverse res)
)

;;; ============================================================
;;; CAMINHO DO ARQUIVO INI DE MEMORIA (PASTA GLOBAL FIXA)
;;; ============================================================
(defun mem-ini-path (/ appdata pasta)
  ;; Usa AppData\Local como base para o historico global
  (setq appdata (getenv "LOCALAPPDATA"))
  (if (or (not appdata) (= appdata ""))
    ;; Fallback: compoe manualmente a partir de USERPROFILE
    (progn
      (setq appdata (getenv "USERPROFILE"))
      (if (or (not appdata) (= appdata ""))
        (setq appdata "C:\\Users\\Default")
      )
      (setq appdata (strcat appdata "\\AppData\\Local"))
    )
  )
  ;; Garante barra no final
  (if (not (wcmatch appdata "*\\,*/*"))
    (setq appdata (strcat appdata "\\"))
  )
  (setq pasta (strcat appdata "NanoCAD_Scripts_CAD"))
  ;; Cria a pasta se nao existir
  (if (not (vl-file-directory-p pasta))
    (vl-mkdir pasta)
  )
  (setq *MEM-INI-PATH* (strcat pasta "\\carimbo_memoria.ini"))
  *MEM-INI-PATH*
)

;;; ============================================================
;;; LEITURA E ESCRITA DO ARQUIVO INI
;;; ============================================================
(defun ini-le-tudo (path / f linha dados chave valor p)
  (setq dados nil)
  (if (findfile path)
    (progn
      (setq f (open path "r"))
      (while (setq linha (read-line f))
        (setq p (vl-string-search "=" linha))
        (if p
          (progn
            (setq chave (substr linha 1 p))
            (setq valor (substr linha (+ p 2)))
            (setq dados (cons (cons chave valor) dados))
          )
        )
      )
      (close f)
    )
  )
  (reverse dados)
)

(defun ini-le (path chave / dados par)
  (setq dados (ini-le-tudo path))
  (setq par (assoc chave dados))
  (if par (cdr par) "")
)

(defun ini-salva-chave (path chave valor / dados outros f par)
  (setq dados (ini-le-tudo path))
  (setq outros nil)
  (foreach par dados
    (if (/= (car par) chave)
      (setq outros (cons par outros))
    )
  )
  (setq outros (reverse outros))
  (setq outros (append outros (list (cons chave valor))))
  
  (setq f (open path "w"))
  (if f
    (progn
      (foreach par outros
        (if (and (car par) (cdr par))
          (write-line (strcat (car par) "=" (cdr par)) f)
        )
      )
      (close f)
    )
    (princ (strcat "\n[AVISO] Sem permissao para salvar o arquivo de memoria em: " path))
  )
)

;;; ============================================================
;;; MEMORIA RAPIDA (GETENV/SETENV)
;;; ============================================================
(defun mem-salva-env (chave valor)
  (setenv (strcat "CARIMBO_" chave) (if valor valor ""))
)
(defun mem-le-env (chave / v)
  (setq v (getenv (strcat "CARIMBO_" chave)))
  (if v v "")
)

;;; ============================================================
;;; GESTAO DO HISTORICO EM LISTAS
;;; ============================================================

(defun carrega-historico (chave-ini / str lista)
  (setq str (ini-le (mem-ini-path) chave-ini))
  (if (= str "") nil (remove-item-lista "" (str-split str "|")))
)

(defun salva-historico (campo-str chave-ini max-items / val lista-atual ini l-count l-nova)
  (setq val (get_tile campo-str))
  (if (and val (/= val ""))
    (progn
      (setq ini (mem-ini-path))
      (setq lista-atual (str-split (ini-le ini chave-ini) "|"))
      (setq lista-atual (remove-item-lista "" lista-atual))
      (setq lista-atual (remove-item-lista val lista-atual))
      ;; Adiciona no topo
      (setq lista-atual (cons val lista-atual))
      
      ;; Limita o tamanho do historico
      (setq l-count 0 l-nova nil)
      (foreach x lista-atual
        (if (< l-count max-items)
          (progn (setq l-nova (cons x l-nova)) (setq l-count (1+ l-count)))
        )
      )
      (setq lista-atual (reverse l-nova))

      ;; Salva no arquivo
      (ini-salva-chave ini chave-ini (str-join lista-atual "|"))
      
      ;; Atualiza variavel global e o DCL
      (cond
        ((= campo-str "OBJETIVO")     (setq *HIST-OBJETIVO* lista-atual)     (atualiza-dropdown "POP_OBJETIVO" *HIST-OBJETIVO*))
        ((= campo-str "SERVICO")      (setq *HIST-SERVICO* lista-atual)      (atualiza-dropdown "POP_SERVICO" *HIST-SERVICO*))
        ((= campo-str "ORCAMENTO")    (setq *HIST-ORCAMENTO* lista-atual)    (atualiza-dropdown "POP_ORCAMENTO" *HIST-ORCAMENTO*))
        ((= campo-str "LEVANTAMENTO") (setq *HIST-LEVANTAMENTO* lista-atual) (atualiza-dropdown "POP_LEVANTAMENTO" *HIST-LEVANTAMENTO*))
        ((= campo-str "DESENHO")      (setq *HIST-DESENHO* lista-atual)      (atualiza-dropdown "POP_DESENHO" *HIST-DESENHO*))
      )
      (princ (strcat "\n[MEM] " campo-str " salvo no historico."))
    )
  )
)

(defun atualiza-dropdown (chave-pop lista)
  (start_list chave-pop)
  (add_list " [ Selecione do Historico ] ")
  (foreach item lista (add_list item))
  (end_list)
  (set_tile chave-pop "0")
)

(defun aplica-historico (chave-edit lista indice-str)
  (setq idx (atoi indice-str))
  (if (> idx 0)
    (set_tile chave-edit (nth (1- idx) lista))
  )
)

;;; ============================================================
;;; CONFIGURACOES DAS LISTAS (DROPDOWNS)
;;; ============================================================
(setq *LISTA-GRAU* (list "Nenhum" "Leve" "Medio" "Grave"))
(setq *LISTA-REGIONAL* (list "Leste" "Centro" "Oeste"))
(setq *LISTA-ESCALA* (list "1:500" "1:1000"))

(defun mapeia-escala-idx (valor-lido / v)
  (if (and valor-lido (/= valor-lido ""))
    (progn
      (setq v (str-replace " " "" (str-replace ":" "" (normaliza-busca valor-lido))))
      (cond
        ((vl-string-search "1000" v) 1)
        ((vl-string-search "500"  v) 0)
        (T 0)
      )
    )
    0
  )
)

;;; ============================================================
;;; CRIACAO DO DCL TEMPORARIO (REORGANIZADO v15.1)
;;; ============================================================
(defun cria-dcl-temp (/ dcl-file f dcl-lines)
  (setq dcl-file (vl-filename-mktemp "carimbo.dcl"))
  (setq f (open dcl-file "w"))
  (setq dcl-lines
    (list
      "carimbo_dlg : dialog {"
      "  label = \"Preencher Carimbo - Engeselt\";"
      "  width = 72;"
      "  : boxed_column {"
      "    label = \"Colar dados da OS\";"
      "    : text { label = \"Cole o texto da OS abaixo (uma linha) e clique em Aplicar:\"; }"
      "    : row {"
      "      : button { key = \"btn_limpar\"; label = \"  Limpar Campos  \"; width = 16; }"
      "    }"
      "    : row {"
      "      : edit_box { key = \"TEXTO_OS\"; width = 56; edit_limit = 2000; fixed_width = true; }"
      "      : button { key = \"btn_colar_os\"; label = \"  Aplicar OS  \"; width = 14; }"
      "    }"
      "  }"
      "  spacer;"
      "  : boxed_column {"
      "    label = \"Objetivo\";"
      "    : row {"
      "      : edit_box { key = \"OBJETIVO\"; width = 42; }"
      "      : popup_list { key = \"POP_OBJETIVO\"; width = 18; }"
      "      : button { key = \"btn_salvar_objetivo\"; label = \" Salvar \"; width = 8; }"
      "    }"
      "  }"
      "  : boxed_column {"
      "    label = \"Status Obras no Local (Conexao)\";"
      "    : radio_row {"
      "      key = \"rad_grupo_obra\";"
      "      : radio_button { key = \"rad_sem_obra\"; label = \"Sem Obras no Local\"; }"
      "      : radio_button { key = \"rad_com_obra\"; label = \"Obras no Local\"; }"
      "    }"
      "    : edit_box { key = \"OBRA_LOCAL_TXT\"; label = \"Especificar Obras:\"; width = 58; }"
      "  }"
      "  : boxed_column {"
      "    label = \"Acesso p/ Caminhao\";"
      "    : radio_row {"
      "      key = \"rad_grupo_acesso\";"
      "      : radio_button { key = \"rad_com_acesso\"; label = \"Com Acesso\"; }"
      "      : radio_button { key = \"rad_sem_acesso\"; label = \"Sem Acesso\"; }"
      "    }"
      "    : edit_box { key = \"ACESSO_TXT\"; label = \"Especificar Pontos:\"; width = 58; }"
      "  }"
      "  : row {"
      "    : boxed_column {"
      "      label = \"Data\"; width = 24;"
      "      : row {"
      "        : edit_box { key = \"DATA\"; width = 12; }"
      "        : button { key = \"btn_hoje\"; label = \"Hoje\"; width = 6; }"
      "      }"
      "    }"
      "    : boxed_column { label = \"Escala\"; width = 20; : popup_list { key = \"ESCALA\"; width = 16; } }"
      "    : boxed_column { label = \"Grau de Risco\"; width = 20; : popup_list { key = \"GRAU_RISCO\"; width = 16; } }"
      "  }"
      "  : row {"
      "    : boxed_column { label = \"Regional\"; width = 30; : popup_list { key = \"REGIONAL\"; width = 26; } }"
      "    : boxed_column { label = \"Alimentador\"; width = 30; : edit_box { key = \"ALIMENTADOR\"; width = 26; } }"
      "  }"
      "  : row {"
      "    : boxed_column { label = \"OS / DM\"; width = 24; : edit_box { key = \"OS_DM\"; width = 20; } }"
      "    : boxed_column { label = \"Componente\"; width = 24; : edit_box { key = \"COMPONENTE\"; width = 20; } }"
      "  }"
      "  : boxed_column {"
      "    label = \"Responsaveis\";"
      "    : row {"
      "      : text { label = \"Levantamento:\"; width = 12; }"
      "      : edit_box { key = \"LEVANTAMENTO\"; width = 30; }"
      "      : popup_list { key = \"POP_LEVANTAMENTO\"; width = 16; }"
      "      : button { key = \"btn_salvar_levantamento\"; label = \"Salvar\"; width = 6; }"
      "    }"
      "    : row {"
      "      : text { label = \"Desenho:\"; width = 12; }"
      "      : edit_box { key = \"DESENHO\"; width = 30; }"
      "      : popup_list { key = \"POP_DESENHO\"; width = 16; }"
      "      : button { key = \"btn_salvar_desenho\"; label = \"Salvar\"; width = 6; }"
      "    }"
      "    : row {"
      "      : text { label = \"Orcamento:\"; width = 12; }"
      "      : edit_box { key = \"ORCAMENTO\"; width = 30; }"
      "      : popup_list { key = \"POP_ORCAMENTO\"; width = 16; }"
      "      : button { key = \"btn_salvar_orcamento\"; label = \"Salvar\"; width = 6; }"
      "    }"
      "  }"
      "  : boxed_column { label = \"Obra N.\"; : edit_box { key = \"OBRA\"; width = 66; } }"
      "  : boxed_column {"
      "    label = \"Servico\";"
      "    : row {"
      "      : edit_box { key = \"SERVICO\"; width = 42; }"
      "      : popup_list { key = \"POP_SERVICO\"; width = 18; }"
      "      : button { key = \"btn_salvar_servico\"; label = \" Salvar \"; width = 8; }"
      "    }"
      "  }"
      "  : boxed_column {"
      "    label = \"Informacoes Compostas\";"
      "    : row {"
      "      : boxed_column { label = \"Solicitante\"; width = 32; : edit_box { key = \"SOLICITANTE\"; width = 28; } }"
      "      : boxed_column { label = \"Local\"; width = 32; : edit_box { key = \"LOCAL\"; width = 28; } }"
      "    }"
      "    : row {"
      "      : boxed_column { label = \"Referencias\"; width = 32; : edit_box { key = \"REFERENCIAS\"; width = 28; } }"
      "      : boxed_column { label = \"Apoios\"; width = 32; : edit_box { key = \"APOIOS\"; width = 28; } }"
      "    }"
      "  }"
      "  : row {"
      "    : button { key = \"aceitar\"; label = \"  Preencher Carimbo  \"; is_default = true; width = 22; }"
      "    : button { key = \"cancelar\"; label = \"  Cancelar  \"; is_cancel = true; width = 14; }"
      "  }"
      "  spacer;"
      "}"
    )
  )
  (foreach line dcl-lines (write-line line f))
  (close f)
  dcl-file
)

;;; ============================================================
;;; LEITURA E LIMPEZA DE TEXTOS
;;; ============================================================

(defun get-full-text (ed / txt item)
  (setq txt "")
  (foreach item ed
    (if (or (= (car item) 1) (= (car item) 3))
      (setq txt (strcat txt (cdr item)))
    )
  )
  txt
)

(defun normaliza-busca (txt / s)
  (setq s (strcase txt))
  (setq s (str-replace (chr 199) "C" s))
  (setq s (str-replace (chr 231) "C" s))
  (setq s (str-replace "\\U+00C7" "C" s))
  (setq s (str-replace "\\U+00E7" "C" s))
  (setq s (str-replace (chr 202) "E" s))
  (setq s (str-replace (chr 234) "E" s))
  (setq s (str-replace "\\U+00CA" "E" s))
  (setq s (str-replace "\\U+00EA" "E" s))
  (setq s (str-replace (chr 201) "E" s))
  (setq s (str-replace (chr 233) "E" s))
  (setq s (str-replace "\\U+00C9" "E" s))
  (setq s (str-replace "\\U+00E9" "E" s))
  (setq s (str-replace (strcat (chr 194) (chr 176)) "O" s))
  (setq s (str-replace (strcat (chr 194) (chr 186)) "O" s))
  (setq s (str-replace (chr 176) "O" s))
  (setq s (str-replace (chr 186) "O" s))
  (setq s (str-replace "\\U+00B0" "O" s))
  (setq s (str-replace "%%D" "O" s))
  (setq s (str-replace "%%d" "O" s))
  s
)

(defun limpa-texto (str modo-completo / res i c c2 j found pos)
  (setq str (str-replace (strcat (chr 194) (chr 176)) (chr 176) str))
  (setq str (str-replace (strcat (chr 194) (chr 186)) (chr 186) str))
  (setq str (str-replace "%%d" (chr 176) str))
  (setq str (str-replace "%%D" (chr 176) str))
  (setq str (str-replace "\\U+00B0" (chr 176) str))
  (setq str (str-replace "\\U+00C7" (chr 199) str))
  (setq str (str-replace "\\U+00E7" (chr 231) str))
  (setq str (str-replace "\\U+00CA" (chr 202) str))
  (setq str (str-replace "\\U+00EA" (chr 234) str))
  (setq str (str-replace "{" "" str))
  (setq str (str-replace "}" "" str))
  (if modo-completo
    (progn
      (setq str (str-replace "\\P" " " str))
      (setq str (str-replace "\\p" " " str))
    )
  )
  (setq res "")
  (setq i 1)
  (while (<= i (strlen str))
    (setq c (substr str i 1))
    (if (and (= c "\\") (< i (strlen str)))
      (progn
        (setq c2 (strcase (substr str (1+ i) 1)))
        (if (wcmatch c2 "L,O")
          (setq i (+ i 2))
          (progn
            (if (wcmatch c2 (if modo-completo "C,H,F,W,T,Q,S,A,P" "C,H,F,W,T,Q,S,A"))
              (progn
                (setq j (+ i 2))
                (setq found nil)
                (while (and (not found) (<= j (strlen str)) (<= j (+ i 50)))
                  (if (= (substr str j 1) ";") (setq found T))
                  (if (not found) (setq j (1+ j)))
                )
                (if found
                  (setq i (1+ j))
                  (progn (setq res (strcat res c)) (setq i (1+ i)))
                )
              )
              (progn (setq res (strcat res c)) (setq i (1+ i)))
            )
          )
        )
      )
      (progn (setq res (strcat res c)) (setq i (1+ i)))
    )
  )
  (setq res (vl-string-trim " " res))
  (if (and modo-completo (setq pos (vl-string-search "    FOLHA" res)))
    (setq res (vl-string-trim " " (substr res 1 pos)))
  )
  res
)

(defun limpa-texto-puro      (str) (limpa-texto str T))
(defun limpa-texto-objetivo (str) (limpa-texto str nil))

(defun atualiza-dxf-texto (ed novo-txt / nova-ed item)
  (setq nova-ed nil)
  (foreach item ed
    (cond
      ((= (car item) 1)  (setq nova-ed (cons (cons 1 novo-txt) nova-ed)))
      ((= (car item) 3)  nil)
      (T                 (setq nova-ed (cons item nova-ed)))
    )
  )
  (reverse nova-ed)
)

(defun get-date-today (/ str y m d)
  (setq str (rtos (getvar "CDATE") 2 0))
  (strcat (substr str 7 2) "/" (substr str 5 2) "/" (substr str 1 4))
)

;;; ============================================================
;;; SISTEMA CENTRAL DE LEITURA
;;; ============================================================
(defun carrega-textos-desenho (/ ss i txt linhas l l_limpa)
  (setq *MEMORIA-TEXTOS* nil)
  (if (setq ss (ssget "X" (list (cons 0 "TEXT,MTEXT") (cons 410 (getvar "CTAB")))))
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq txt (get-full-text (entget (ssname ss i))))
        (setq txt (str-replace "\\P" "\n" (str-replace "\\p" "\n" txt)))
        (setq linhas (str-split txt "\n"))
        (foreach l linhas
          (setq l_limpa (limpa-texto-puro l))
          (if (vl-string-search ":" l_limpa)
            (setq *MEMORIA-TEXTOS* (cons (cons l_limpa (normaliza-busca l_limpa)) *MEMORIA-TEXTOS*))
          )
        )
        (setq i (1+ i))
      )
      (setq *MEMORIA-TEXTOS* (reverse *MEMORIA-TEXTOS*))
    )
  )
)

(defun extrai-campo (frags / res achou raw norm p_dois match)
  (setq res "")
  (setq achou nil)
  (foreach item *MEMORIA-TEXTOS*
    (if (not achou)
      (progn
        (setq raw (car item))
        (setq norm (cdr item))
        (setq match T)
        (foreach f frags
          (if (not (vl-string-search f norm)) (setq match nil))
        )
        (if match
          (progn
            (setq p_dois (vl-string-search ":" raw))
            (if p_dois
              (progn
                (setq res (vl-string-trim " " (substr raw (+ p_dois 2))))
                (setq achou T)
              )
            )
          )
        )
      )
    )
  )
  res
)

(defun extrai-objetivo-completo (/ ss i ent txt txt-limpo txt-norm p-dois res achou)
  (setq res "") (setq achou nil)
  (if (setq ss (ssget "X" (list '(0 . "TEXT,MTEXT") (cons 410 (getvar "CTAB")))))
    (progn
      (setq i 0)
      (while (and (< i (sslength ss)) (not achou))
        (setq txt (get-full-text (entget (ssname ss i))))
        (setq txt (str-replace "\n" "\\P" (str-replace "\r" "" txt)))
        (setq txt-limpo (limpa-texto-objetivo txt))
        (setq txt-norm (normaliza-busca txt-limpo))
        (if (vl-string-search "OBJETIV" txt-norm)
          (progn
            (setq p-dois (vl-string-search ":" txt-limpo))
            (if p-dois (setq res (vl-string-trim " " (substr txt-limpo (+ p-dois 2)))))
            (setq achou T)
          )
        )
        (setq i (1+ i))
      )
    )
  )
  res
)

(defun extrai-obras-local-cad (/ ss i ent txt txt-limpo txt-norm p-barra pos-texto str-busca pos-obra txt-ext res achou)
  (setq res (cons nil "")) (setq achou nil)
  (if (setq ss (ssget "X" (list '(0 . "TEXT,MTEXT") (cons 410 (getvar "CTAB")))))
    (progn
      (setq i 0)
      (while (and (< i (sslength ss)) (not achou))
        (setq txt (get-full-text (entget (ssname ss i))))
        (setq txt (str-replace "\n" "\\P" (str-replace "\r" "" txt)))
        (setq txt-limpo (limpa-texto-objetivo txt))
        (setq txt-norm (normaliza-busca txt-limpo))
        (if (vl-string-search "PONTO DE CONEX" txt-norm)
          (progn
            (setq p-barra (vl-string-search "\\P" (strcase txt)))
            (if p-barra
              (progn
                (setq pos-texto (vl-string-trim " }" (substr txt-limpo (+ p-barra 3))))
                (setq str-busca (normaliza-busca pos-texto))
                (cond
                  ((or (vl-string-search "SEM OBRA NO LOCAL" str-busca)
                       (vl-string-search "SEM OBRAS NO LOCAL" str-busca))
                   (setq res (cons nil "")))
                  ((setq pos-obra (vl-string-search "OBRAS NO LOCAL" str-busca))
                   (setq res (cons T (substr pos-texto (+ pos-obra 15)))))
                  ((setq pos-obra (vl-string-search "OBRA NO LOCAL" str-busca))
                   (setq res (cons T (substr pos-texto (+ pos-obra 14)))))
                )
                (if (car res)
                  (progn
                    (setq txt-ext (vl-string-trim " " (cdr res)))
                    (if (= (substr txt-ext 1 1) ":") (setq txt-ext (vl-string-trim " " (substr txt-ext 2))))
                    (setq res (cons T (vl-string-trim " }" txt-ext)))
                  )
                )
              )
            )
            (setq achou T)
          )
        )
        (setq i (1+ i))
      )
    )
  )
  res
)

(defun extrai-acesso-caminhao-cad (/ ss i ent txt txt-limpo txt-sem-p str-busca pos-pontos txt-ext res achou)
  (setq res (cons nil "")) (setq achou nil)
  (if (setq ss (ssget "X" (list '(0 . "TEXT,MTEXT") (cons 410 (getvar "CTAB")))))
    (progn
      (setq i 0)
      (while (and (< i (sslength ss)) (not achou))
        (setq txt (get-full-text (entget (ssname ss i))))
        (setq txt (str-replace "\n" "\\P" (str-replace "\r" "" txt)))
        (setq txt-limpo (limpa-texto-objetivo txt))
        (setq txt-sem-p (str-replace "\\P" " " (strcase txt-limpo)))
        (setq str-busca (normaliza-busca txt-sem-p))
        (if (and (vl-string-search "ACESSO" str-busca) (vl-string-search "CAMINH" str-busca))
          (progn
            (cond
              ((setq pos-pontos (vl-string-search "PONTOS:" txt-sem-p))
               (setq txt-ext (substr txt-sem-p (+ pos-pontos 8)))
               (setq res (cons T (vl-string-trim " }" txt-ext))))
              ((vl-string-search "SEM ACESSO" str-busca)
               (setq res (cons T "")))
              (T (setq res (cons nil "")))
            )
            (setq achou T)
          )
        )
        (setq i (1+ i))
      )
    )
  )
  res
)

(defun seta-popup-indice (chave_dcl valor_lido lista / i achou v_limpo l_limpo)
  (if (and valor_lido (/= valor_lido ""))
    (progn
      (setq v_limpo (normaliza-busca valor_lido))
      (setq i 0) (setq achou nil)
      (while (and (< i (length lista)) (not achou))
        (setq l_limpo (normaliza-busca (nth i lista)))
        (if (or (wcmatch v_limpo (strcat "*" l_limpo "*"))
                (wcmatch l_limpo (strcat "*" v_limpo "*"))
                (= v_limpo l_limpo))
          (progn (set_tile chave_dcl (itoa i)) (setq achou T))
        )
        (setq i (1+ i))
      )
    )
  )
)

;;; ============================================================
;;; LIMPAR CAMPOS DO DIALOGO
;;; ============================================================
(defun limpa-campos-dialogo (/ reg-idx)
  (set_tile "DATA"          "")
  (set_tile "COMPONENTE"    "")
  (set_tile "ALIMENTADOR"   "")
  (set_tile "OS_DM"         "")
  (set_tile "OBRA"          "")
  (set_tile "SOLICITANTE"   "")
  (set_tile "LOCAL"         "")
  (set_tile "REFERENCIAS"   "SEM REF")
  (set_tile "APOIOS"        "")
  (set_tile "TEXTO_OS"      "")
  (set_tile "ESCALA"        "0")
  (set_tile "GRAU_RISCO"    "0")
  
  ;; Campos com historico ficam VAZIOS
  (set_tile "SERVICO"       "")
  (set_tile "OBJETIVO"      "")
  (set_tile "ORCAMENTO"     "")
  (set_tile "DESENHO"       "")
  (set_tile "LEVANTAMENTO"  "")
  
  ;; Reseta Dropdowns
  (set_tile "POP_SERVICO"      "0")
  (set_tile "POP_OBJETIVO"     "0")
  (set_tile "POP_ORCAMENTO"    "0")
  (set_tile "POP_DESENHO"      "0")
  (set_tile "POP_LEVANTAMENTO" "0")

  ;; Regional
  (setq reg-idx (mem-le-env "REGIONAL_IDX"))
  (if (= reg-idx "") (setq reg-idx "0"))
  (set_tile "REGIONAL" reg-idx)
  
  ;; Obras no local e Acesso
  (set_tile "rad_sem_obra" "1") (set_tile "rad_com_obra" "0")
  (set_tile "OBRA_LOCAL_TXT" "") (mode_tile "OBRA_LOCAL_TXT" 1)
  (set_tile "rad_com_acesso" "1") (set_tile "rad_sem_acesso" "0")
  (set_tile "ACESSO_TXT" "") (mode_tile "ACESSO_TXT" 1)
  (princ "\n[CARIMBO] Campos limpos com sucesso.")
)

;;; ============================================================
;;; PARSER DA OS
;;; ============================================================
(defun normaliza-pipes (texto / r)
  (setq r (str-replace "|" " " texto))
  (setq r (str-replace (chr 10) " " r))
  (setq r (str-replace (chr 13) "" r))
  (setq r (str-replace (strcat (chr 194) (chr 160)) " " r))
  (setq r (str-replace (chr 160) " " r))
  (setq r (str-replace (strcat (chr 194) (chr 176)) (chr 176) r))
  (setq r (str-replace (strcat (chr 194) (chr 186)) (chr 186) r))
  (setq r (str-replace (strcat "ENDERE" (strcat (chr 195) (chr 135)) "O:") "ENDERECO:" r))
  (setq r (str-replace (strcat "ENDERE" (strcat (chr 195) (chr 167)) "O:") "ENDERECO:" r))
  (setq r (str-replace (strcat "ENDERE" (chr 199) "O:") "ENDERECO:" r))
  (setq r (str-replace (strcat "ENDERE" (chr 231) "O:") "ENDERECO:" r))
  (setq r (str-replace "ENDEREÇO:" "ENDERECO:" r))
  (setq r (str-replace (strcat "OR" (strcat (chr 195) (chr 135)) "AMENTO:") "ORCAMENTO:" r))
  (setq r (str-replace (strcat "OR" (strcat (chr 195) (chr 167)) "AMENTO:") "ORCAMENTO:" r))
  (setq r (str-replace "ORÇAMENTO:" "ORCAMENTO:" r))
  (setq r (str-replace (strcat "SERVI" (strcat (chr 195) (chr 135)) "O:") "SERVICO:" r))
  (setq r (str-replace (strcat "SERVI" (strcat (chr 195) (chr 167)) "O:") "SERVICO:" r))
  (setq r (str-replace "SERVIÇO:" "SERVICO:" r))
  (while (vl-string-search "  " r) (setq r (str-replace "  " " " r)))
  (setq r (str-replace (strcat "N" (chr 186) " OBRA:") "NOBS:" r))
  (setq r (str-replace (strcat "N" (chr 176) " OBRA:") "NOBS:" r))
  r
)

(defun busca-chave (texto lista-chaves / ch pos melhor melhor-pos)
  (setq melhor nil) (setq melhor-pos 999999)
  (foreach ch lista-chaves
    (setq pos (vl-string-search ch texto))
    (if (and pos (< pos melhor-pos))
      (progn (setq melhor-pos pos) (setq melhor (list pos (strlen ch))))
    )
  )
  melhor
)

(defun parse-campo-v (texto lista-chaves / todas-delim achado pos-ini pos-fim ch prox resultado)
  (setq todas-delim
    (list "OS:" "DM:" "ALIM:" "COMP:" "NOBS:" "OBRA:" "SOLICITANTE:"
          "ENDERECO:" "TEC:" "DATA:" "ESCALA:" "REGIONAL:" "SERVICO:"
          "DESENHO:" "LEVANTAMENTO:" "ORCAMENTO:" "COMPONENTE:" "ALIMENTADOR:" "OBJETIVO:"))
  (setq achado (busca-chave texto lista-chaves))
  (if (not achado)
    ""
    (progn
      (setq pos-ini (+ (car achado) (cadr achado)))
      (while (and (< pos-ini (strlen texto)) (wcmatch (substr texto (1+ pos-ini) 1) " ,:"))
        (setq pos-ini (1+ pos-ini))
      )
      (setq pos-fim (strlen texto))
      (foreach ch todas-delim
        (setq prox (vl-string-search ch texto pos-ini))
        (if (and prox (< prox pos-fim)) (setq pos-fim prox))
      )
      (vl-string-trim " " (substr texto (1+ pos-ini) (- pos-fim pos-ini)))
    )
  )
)

(defun aplica-os-no-dialogo (/ tx p-os p-dm p-alim p-comp p-obra p-solicitante
                                p-local p-tec p-objetivo p-servico p-desenho
                                p-orcamento p-regional os-dm p-escala)
  (setq tx (get_tile "TEXTO_OS"))
  (if (or (not tx) (= tx ""))
    (princ "\n[OS] Campo TEXTO_OS vazio.")
    (progn
      (setq tx (normaliza-pipes tx))
      (setq p-os          (parse-campo-v tx (list "OS:")))
      (setq p-dm          (parse-campo-v tx (list "DM:")))
      (setq p-alim        (parse-campo-v tx (list "ALIM:")))
      (setq p-comp        (parse-campo-v tx (list "COMP:")))
      (setq p-obra        (parse-campo-v tx (list "NOBS:" "OBRA:")))
      (setq p-solicitante (parse-campo-v tx (list "SOLICITANTE:")))
      (setq p-local       (parse-campo-v tx (list "ENDERECO:")))
      (setq p-tec         (parse-campo-v tx (list "TEC:")))
      (setq p-objetivo    (parse-campo-v tx (list "OBJETIVO:")))
      (setq p-servico     (parse-campo-v tx (list "SERVICO:")))
      (setq p-desenho     (parse-campo-v tx (list "DESENHO:")))
      (setq p-orcamento   (parse-campo-v tx (list "ORCAMENTO:")))
      (setq p-regional    (parse-campo-v tx (list "REGIONAL:")))
      (setq p-escala      (parse-campo-v tx (list "ESCALA:")))
      (setq os-dm
        (cond
          ((and (/= p-os "") (/= p-dm "")) (strcat p-os "/" p-dm))
          ((/= p-os "") p-os)
          ((/= p-dm "") p-dm)
          (T "")
        )
      )
      (if (/= os-dm "")         (set_tile "OS_DM"        os-dm))
      (if (/= p-alim "")        (set_tile "ALIMENTADOR"  p-alim))
      (if (/= p-comp "")        (set_tile "COMPONENTE"   p-comp))
      (if (/= p-solicitante "") (set_tile "SOLICITANTE"  p-solicitante))
      (if (/= p-local "")       (set_tile "LOCAL"        p-local))
      (if (/= p-tec "")         (set_tile "LEVANTAMENTO" p-tec))
      (if (/= p-obra "")        (set_tile "OBRA"         p-obra))
      (if (/= p-objetivo "")    (set_tile "OBJETIVO"     p-objetivo))
      (if (/= p-servico "")     (set_tile "SERVICO"      p-servico))
      (if (/= p-desenho "")     (set_tile "DESENHO"      p-desenho))
      (if (/= p-orcamento "")   (set_tile "ORCAMENTO"    p-orcamento))
      (if (/= p-regional "")    (seta-popup-indice "REGIONAL" p-regional *LISTA-REGIONAL*))
      (if (/= p-escala "")      (set_tile "ESCALA" (itoa (mapeia-escala-idx p-escala))))
      (princ "\n[OS] Processado com sucesso!")
    )
  )
)

;;; ============================================================
;;; SUBSTITUICAO DIRETA DE CAMPOS NO TEXTO DO MTEXT
;;; ============================================================
(defun acha-chave-raw (txt chave-norm / norm p)
  (setq norm (normaliza-busca txt))
  (vl-string-search chave-norm norm)
)

(defun localiza-valor-raw (txt pos-apos-dois lista-proximas-norm / norm pos-fim p)
  (while (and (< pos-apos-dois (strlen txt))
              (= (substr txt (1+ pos-apos-dois) 1) " "))
    (setq pos-apos-dois (1+ pos-apos-dois))
  )
  (setq norm (normaliza-busca txt))
  (setq pos-fim (strlen txt))
  (setq p (vl-string-search "\\P" (strcase txt) pos-apos-dois))
  (if (and p (< p pos-fim)) (setq pos-fim p))
  (foreach cn lista-proximas-norm
    (setq p (vl-string-search cn norm pos-apos-dois))
    (if (and p (< p pos-fim)) (setq pos-fim p))
  )
  (cons pos-apos-dois pos-fim)
)

(defun subst-chave-raw (txt chave-norm novo-val lista-proximas-norm
                        / pos-chave pos-apos-dois intervalo antes depois len-chave)
  (setq pos-chave (acha-chave-raw txt chave-norm))
  (if (not pos-chave)
    txt
    (progn
      (setq len-chave (strlen chave-norm))
      (setq pos-apos-dois (+ pos-chave len-chave))
      (setq p-dois-real (vl-string-search ":" txt pos-chave))
      (if (and p-dois-real (< p-dois-real (+ pos-chave len-chave 5)))
        (setq pos-apos-dois (1+ p-dois-real))
      )
      (setq intervalo (localiza-valor-raw txt pos-apos-dois lista-proximas-norm))
      (setq antes  (substr txt 1 (car intervalo)))
      (setq depois (substr txt (1+ (cdr intervalo))))
      (setq depois (vl-string-trim-left " " depois))
      (setq txt (strcat antes novo-val (if (> (strlen depois) 0) " " "") depois))
      txt
    )
  )
)

(defun vl-string-trim-left (chars str / i)
  (setq i 1)
  (while (and (<= i (strlen str))
              (wcmatch (substr str i 1) (strcat "[" chars "]")))
    (setq i (1+ i))
  )
  (substr str i)
)

(defun texto-tem-campo-agrupado (txt-raw / norm flat)
  (setq flat (str-replace "\\P" " " (str-replace "\\p" " " txt-raw)))
  (setq norm (normaliza-busca flat))
  (or (vl-string-search "SOLICITANTE:" norm)
      (vl-string-search "LOCAL:" norm)
      (vl-string-search "REFERENCIAS:" norm)
      (vl-string-search "REFERENC" norm)
      (vl-string-search "APOIOS:" norm))
)

(defun injeta-campos-agrupados (txt-raw v-sol v-loc v-ref v-apo / resultado)
  (setq resultado txt-raw)
  (setq resultado (subst-chave-raw resultado "SOLICITANTE:" v-sol (list "LOCAL:" "REFER" "APOIOS:")))
  (setq resultado (subst-chave-raw resultado "LOCAL:" v-loc (list "REFER" "APOIOS:")))
  (if (acha-chave-raw resultado "REFERENCIAS:")
    (setq resultado (subst-chave-raw resultado "REFERENCIAS:" v-ref (list "APOIOS:")))
    (progn
      (setq p-ref (acha-chave-raw resultado "REFER"))
      (if p-ref
        (progn
          (setq p-dois-ref (vl-string-search ":" resultado p-ref))
          (if (and p-dois-ref (< p-dois-ref (+ p-ref 20)))
            (progn
              (setq chave-exata-norm (normaliza-busca (substr resultado (1+ p-ref) (1+ (- p-dois-ref p-ref)))))
              (setq resultado (subst-chave-raw resultado chave-exata-norm v-ref (list "APOIOS:")))
            )
          )
        )
      )
    )
  )
  (setq resultado (subst-chave-raw resultado "APOIOS:" v-apo (list)))
  resultado
)

;;; ============================================================
;;; COMANDO PRINCIPAL
;;; ============================================================
(defun c:CARIMBO (/ dcl-id resultado dcl-path *MEMORIA-TEXTOS*
                    v-data v-escala v-componente v-levantamento
                    v-alimentador v-desenho v-os_dm v-grau_risco
                    v-orcamento v-regional v-servico v-objetivo v-obra
                    v-solicitante v-local v-referencias v-apoios
                    v-obra-local-tipo v-obra-local-txt v-obra_local_final
                    v-acesso-tipo v-acesso-txt v-acesso_final
                    escala-lida escala-idx
                    ss i ent ed txt linhas l l-limpa l-norm nova-linha
                    p-dois p-real-dois tem-chave prefixo campo-achado match frag
                    f-map valor-campo suf_folha p_f txt-final item
                    is-objetivo is-obra-local is-acesso is-agrupado
                    txt-safe p-barra p-conex obra-local-data acesso-data
                    l-limpa-temp str-busca-temp
                    regional-idx-str ini-path
                    obj-lido orc-lido des-lido lev-lido reg-lido srv-lido ref-lida)

  (if (not (wcmatch (strcase (getvar "CTAB")) "IMPRESS*,*LAYOUT*"))
    (progn (princ "\n[BLOQUEADO] Va para uma aba LAYOUT ou IMPRESSAO primeiro.") (princ) (exit))
  )

  (setq ini-path (mem-ini-path))

  (setq dcl-path (cria-dcl-temp))
  (setq dcl-id (load_dialog dcl-path))
  (if (< dcl-id 0)
    (progn (princ "\n[ERRO] DCL nao pode ser carregado.") (vl-file-delete dcl-path) (princ) (exit))
  )
  (if (not (new_dialog "carimbo_dlg" dcl-id))
    (progn (princ "\n[ERRO] Dialogo nao encontrado.") (unload_dialog dcl-id) (vl-file-delete dcl-path) (exit))
  )

  ;; Popula listas Basicas
  (start_list "GRAU_RISCO")  (foreach item *LISTA-GRAU* (add_list item)) (end_list) (set_tile "GRAU_RISCO" "0")
  (start_list "REGIONAL")    (foreach item *LISTA-REGIONAL* (add_list item)) (end_list) (set_tile "REGIONAL"   "0")
  (start_list "ESCALA")      (foreach item *LISTA-ESCALA* (add_list item)) (end_list) (set_tile "ESCALA"     "0")

  ;; Carrega Historicos
  (setq *HIST-OBJETIVO* (carrega-historico "HIST_OBJETIVO"))
  (setq *HIST-SERVICO* (carrega-historico "HIST_SERVICO"))
  (setq *HIST-ORCAMENTO* (carrega-historico "HIST_ORCAMENTO"))
  (setq *HIST-LEVANTAMENTO* (carrega-historico "HIST_LEVANTAMENTO"))
  (setq *HIST-DESENHO* (carrega-historico "HIST_DESENHO"))

  (atualiza-dropdown "POP_OBJETIVO"     *HIST-OBJETIVO*)
  (atualiza-dropdown "POP_SERVICO"      *HIST-SERVICO*)
  (atualiza-dropdown "POP_ORCAMENTO"    *HIST-ORCAMENTO*)
  (atualiza-dropdown "POP_LEVANTAMENTO" *HIST-LEVANTAMENTO*)
  (atualiza-dropdown "POP_DESENHO"      *HIST-DESENHO*)

  (princ "\n[CARIMBO] Escaneando a prancha...")
  (carrega-textos-desenho)

  ;; Campos simples
  (set_tile "DATA"         (extrai-campo '("DATA")))
  (set_tile "ALIMENTADOR"  (extrai-campo '("ALIMENTADOR")))
  (set_tile "COMPONENTE"   (extrai-campo '("COMPONENTE")))
  (set_tile "OS_DM"        (extrai-campo '("OS" "DM")))
  (set_tile "OBRA"         (extrai-campo '("OBRA N")))
  (set_tile "SOLICITANTE"  (extrai-campo '("SOLICITANTE")))
  (set_tile "LOCAL"        (extrai-campo '("LOCAL")))
  (set_tile "APOIOS"       (extrai-campo '("APOIOS")))

  (setq ref-lida (extrai-campo '("REFER")))
  (set_tile "REFERENCIAS" (if (or (not ref-lida) (= ref-lida "")) "SEM REF" ref-lida))

  ;; Escala
  (setq escala-lida (extrai-campo '("ESCALA")))
  (set_tile "ESCALA" (itoa (mapeia-escala-idx escala-lida)))

  ;; --- CAMPOS COM HISTORICO ---
  (setq obj-lido (extrai-objetivo-completo))
  (set_tile "OBJETIVO"
    (if (or (not obj-lido) (= obj-lido "")) (if *HIST-OBJETIVO* (car *HIST-OBJETIVO*) "") obj-lido))

  (setq srv-lido (extrai-campo '("SERVI")))
  (set_tile "SERVICO"
    (if (or (not srv-lido) (= srv-lido "")) (if *HIST-SERVICO* (car *HIST-SERVICO*) "") srv-lido))

  (setq orc-lido (extrai-campo '("ORCAMENTO")))
  (set_tile "ORCAMENTO"
    (if (or (not orc-lido) (= orc-lido "")) (if *HIST-ORCAMENTO* (car *HIST-ORCAMENTO*) "") orc-lido))

  (setq lev-lido (extrai-campo '("LEVANTAMENTO")))
  (set_tile "LEVANTAMENTO"
    (if (or (not lev-lido) (= lev-lido "")) (if *HIST-LEVANTAMENTO* (car *HIST-LEVANTAMENTO*) "") lev-lido))

  (setq des-lido (extrai-campo '("DESENHO")))
  (set_tile "DESENHO"
    (if (or (not des-lido) (= des-lido "")) (if *HIST-DESENHO* (car *HIST-DESENHO*) "") des-lido))

  (seta-popup-indice "GRAU_RISCO" (extrai-campo '("GRAU DE RISCO")) *LISTA-GRAU*)

  ;; Regional
  (setq reg-lido (extrai-campo '("REGIONAL")))
  (if (or (not reg-lido) (= reg-lido ""))
    (progn
      (setq regional-idx-str (mem-le-env "REGIONAL_IDX"))
      (if (= regional-idx-str "") (setq regional-idx-str "0"))
      (set_tile "REGIONAL" regional-idx-str)
    )
    (seta-popup-indice "REGIONAL" reg-lido *LISTA-REGIONAL*)
  )

  ;; Obras no local
  (setq obra-local-data (extrai-obras-local-cad))
  (if (car obra-local-data)
    (progn
      (set_tile "rad_com_obra" "1") (set_tile "rad_sem_obra" "0")
      (set_tile "OBRA_LOCAL_TXT" (cdr obra-local-data)) (mode_tile "OBRA_LOCAL_TXT" 0))
    (progn
      (set_tile "rad_sem_obra" "1") (set_tile "rad_com_obra" "0")
      (set_tile "OBRA_LOCAL_TXT" "") (mode_tile "OBRA_LOCAL_TXT" 1))
  )

  ;; Acesso
  (setq acesso-data (extrai-acesso-caminhao-cad))
  (if (car acesso-data)
    (progn
      (set_tile "rad_sem_acesso" "1") (set_tile "rad_com_acesso" "0")
      (set_tile "ACESSO_TXT" (cdr acesso-data)) (mode_tile "ACESSO_TXT" 0))
    (progn
      (set_tile "rad_com_acesso" "1") (set_tile "rad_sem_acesso" "0")
      (set_tile "ACESSO_TXT" "") (mode_tile "ACESSO_TXT" 1))
  )

  (setq *MEMORIA-TEXTOS* nil)

  ;; --- ACOES UI ---
  (action_tile "btn_colar_os"        "(aplica-os-no-dialogo)")
  (action_tile "btn_limpar"          "(limpa-campos-dialogo)")
  (action_tile "btn_hoje"            (strcat "(set_tile \"DATA\" \"" (get-date-today) "\")"))
  
  ;; Botoes Salvar Historico
  (action_tile "btn_salvar_objetivo"     "(salva-historico \"OBJETIVO\" \"HIST_OBJETIVO\" 15)")
  (action_tile "btn_salvar_servico"      "(salva-historico \"SERVICO\" \"HIST_SERVICO\" 15)")
  (action_tile "btn_salvar_orcamento"    "(salva-historico \"ORCAMENTO\" \"HIST_ORCAMENTO\" 15)")
  (action_tile "btn_salvar_levantamento" "(salva-historico \"LEVANTAMENTO\" \"HIST_LEVANTAMENTO\" 15)")
  (action_tile "btn_salvar_desenho"      "(salva-historico \"DESENHO\" \"HIST_DESENHO\" 15)")

  ;; Interacao das Listas Suspensas (Dropdown -> Edit_box)
  (action_tile "POP_OBJETIVO"     "(aplica-historico \"OBJETIVO\" *HIST-OBJETIVO* $value)")
  (action_tile "POP_SERVICO"      "(aplica-historico \"SERVICO\" *HIST-SERVICO* $value)")
  (action_tile "POP_ORCAMENTO"    "(aplica-historico \"ORCAMENTO\" *HIST-ORCAMENTO* $value)")
  (action_tile "POP_LEVANTAMENTO" "(aplica-historico \"LEVANTAMENTO\" *HIST-LEVANTAMENTO* $value)")
  (action_tile "POP_DESENHO"      "(aplica-historico \"DESENHO\" *HIST-DESENHO* $value)")

  (action_tile "rad_sem_obra"    "(mode_tile \"OBRA_LOCAL_TXT\" 1)")
  (action_tile "rad_com_obra"    "(mode_tile \"OBRA_LOCAL_TXT\" 0)")
  (action_tile "rad_com_acesso"  "(mode_tile \"ACESSO_TXT\" 1)")
  (action_tile "rad_sem_acesso"  "(mode_tile \"ACESSO_TXT\" 0)")

  (action_tile "cancelar" "(done_dialog 0)")

  (action_tile "aceitar"
    (strcat
      "(setq v-data         (get_tile \"DATA\"))"
      "(setq v-escala       (nth (atoi (get_tile \"ESCALA\")) *LISTA-ESCALA*))"
      "(setq v-componente   (get_tile \"COMPONENTE\"))"
      "(setq v-levantamento (get_tile \"LEVANTAMENTO\"))"
      "(setq v-alimentador  (get_tile \"ALIMENTADOR\"))"
      "(setq v-desenho      (get_tile \"DESENHO\"))"
      "(setq v-os_dm        (get_tile \"OS_DM\"))"
      "(setq v-grau_risco   (nth (atoi (get_tile \"GRAU_RISCO\")) *LISTA-GRAU*))"
      "(setq v-orcamento    (get_tile \"ORCAMENTO\"))"
      "(setq regional-idx-str (get_tile \"REGIONAL\"))"
      "(setq v-regional     (nth (atoi regional-idx-str) *LISTA-REGIONAL*))"
      "(setq v-servico      (get_tile \"SERVICO\"))"
      "(setq v-objetivo     (get_tile \"OBJETIVO\"))"
      "(setq v-obra         (get_tile \"OBRA\"))"
      "(setq v-solicitante  (get_tile \"SOLICITANTE\"))"
      "(setq v-local        (get_tile \"LOCAL\"))"
      "(setq v-referencias  (get_tile \"REFERENCIAS\"))"
      "(setq v-apoios       (get_tile \"APOIOS\"))"
      "(setq v-obra-local-tipo (get_tile \"rad_com_obra\"))"
      "(setq v-obra-local-txt  (get_tile \"OBRA_LOCAL_TXT\"))"
      "(setq v-acesso-tipo  (get_tile \"rad_sem_acesso\"))"
      "(setq v-acesso-txt   (get_tile \"ACESSO_TXT\"))"
      "(done_dialog 1)"
    )
  )

  (setq resultado (start_dialog))
  (unload_dialog dcl-id)
  (vl-file-delete dcl-path)

  (if (/= resultado 1) (progn (princ "\n[CARIMBO] Cancelado.") (princ) (exit)))

  ;; Salva memoria do dropdown "Regional"
  (mem-salva-env "REGIONAL_IDX" regional-idx-str)

  ;; Normaliza valores para o carimbo (uppercase)
  (setq v-data         (strcase v-data))
  (setq v-escala       (strcase v-escala))
  (setq v-componente   (strcase v-componente))
  (setq v-levantamento (strcase v-levantamento))
  (setq v-alimentador  (strcase v-alimentador))
  (setq v-desenho      (strcase v-desenho))
  (setq v-os_dm        (strcase v-os_dm))
  (setq v-grau_risco   (strcase v-grau_risco))
  (setq v-orcamento    (strcase v-orcamento))
  (setq v-regional     (strcase v-regional))
  (setq v-servico      (strcase v-servico))
  (setq v-objetivo     (strcase (str-replace "\\P" " " v-objetivo)))
  (setq v-obra         (strcase v-obra))
  (setq v-solicitante  (strcase v-solicitante))
  (setq v-local        (strcase v-local))
  (setq v-referencias  (strcase v-referencias))
  (setq v-apoios       (strcase v-apoios))

  (if (or (not v-referencias) (= v-referencias ""))
    (setq v-referencias "SEM REF")
  )

  (if (= v-obra-local-tipo "1")
    (setq v-obra_local_final (strcat "OBRAS NO LOCAL: " (strcase v-obra-local-txt)))
    (setq v-obra_local_final "SEM OBRAS NO LOCAL")
  )

  (if (= v-acesso-tipo "1")
    (setq v-acesso_final (strcat "LOCAL SEM ACESSO P/ CAMINH\\U+00C3O NOS PONTOS: " (strcase v-acesso-txt)))
    (setq v-acesso_final "LOCAL COM ACESSO P/ \\P CAMINH\\U+00C3O")
  )

  (princ "\n[CARIMBO] Injetando dados nos carimbos do layout...")

  (if (setq ss (ssget "X" (list '(0 . "TEXT,MTEXT") (cons 410 (getvar "CTAB")))))
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i))
        (setq ed  (entget ent))
        (setq txt (get-full-text ed))

        (setq txt-safe (str-replace "\n" "\\P" (str-replace "\r" "" txt)))
        (setq l-limpa-temp (limpa-texto-objetivo txt-safe))
        (setq str-busca-temp (normaliza-busca (str-replace "\\P" " " l-limpa-temp)))

        (setq is-objetivo   nil)
        (setq is-obra-local nil)
        (setq is-acesso     nil)
        (setq is-agrupado   nil)

        (if (and (vl-string-search ":" l-limpa-temp)
                 (vl-string-search "OBJETIV" str-busca-temp))
          (setq is-objetivo T)
        )
        (if (vl-string-search "PONTO DE CONEX" str-busca-temp)
          (setq is-obra-local T)
        )
        (if (and (vl-string-search "ACESSO" str-busca-temp)
                 (vl-string-search "CAMINH" str-busca-temp))
          (setq is-acesso T)
        )
        (if (and (not is-objetivo) (not is-obra-local) (not is-acesso))
          (if (texto-tem-campo-agrupado txt-safe)
            (setq is-agrupado T)
          )
        )

        (cond
          ;; ---- OBJETIVO ----
          (is-objetivo
            (progn
              (setq p-real-dois (vl-string-search ":" txt-safe))
              (if p-real-dois
                (progn
                  (setq prefixo (substr txt-safe 1 (1+ p-real-dois)))
                  (setq tem-chave (= (substr txt-safe (strlen txt-safe) 1) "}"))
                  (setq suf_folha "")
                  (setq p_f (vl-string-search "FOLHA" (strcase txt-safe)))
                  (if p_f
                    (progn
                      (setq suf_folha (substr txt-safe (1+ p_f)))
                      (if (= (substr suf_folha (strlen suf_folha) 1) "}")
                        (setq suf_folha (substr suf_folha 1 (1- (strlen suf_folha))))
                      )
                      (setq suf_folha (strcat "    " (vl-string-trim " " suf_folha)))
                    )
                  )
                  (setq txt-final (strcat prefixo " " v-objetivo suf_folha (if tem-chave "}" "")))
                  (setq ed (atualiza-dxf-texto ed txt-final))
                  (entmod ed) (entupd ent)
                )
              )
            )
          )

          ;; ---- OBRAS NO LOCAL ----
          (is-obra-local
            (progn
              (setq p-conex (vl-string-search "CONEX" (strcase txt-safe)))
              (if p-conex
                (setq p-barra (vl-string-search "\\P" (strcase txt-safe) p-conex))
                (setq p-barra (vl-string-search "\\P" (strcase txt-safe)))
              )
              (setq tem-chave (= (substr txt-safe (strlen txt-safe) 1) "}"))
              (if p-barra
                (setq prefixo (substr txt-safe 1 (+ p-barra 2)))
                (setq prefixo (if tem-chave "{SEM PONTO DE CONEX\\U+00C3O \\P" "SEM PONTO DE CONEX\\U+00C3O \\P"))
              )
              (setq txt-final (strcat prefixo v-obra_local_final (if tem-chave "}" "")))
              (setq ed (atualiza-dxf-texto ed txt-final))
              (entmod ed) (entupd ent)
            )
          )

          ;; ---- ACESSO P/ CAMINHAO ----
          (is-acesso
            (progn
              (setq p-local (vl-string-search "LOCAL " (strcase txt-safe)))
              (setq tem-chave (= (substr txt-safe (strlen txt-safe) 1) "}"))
              (if p-local
                (setq prefixo (substr txt-safe 1 p-local))
                (setq prefixo (if tem-chave "{\\pxqc;" "\\pxqc;"))
              )
              (setq txt-final (strcat prefixo v-acesso_final (if tem-chave "}" "")))
              (setq ed (atualiza-dxf-texto ed txt-final))
              (entmod ed) (entupd ent)
            )
          )

          ;; ---- CAMPOS AGRUPADOS ----
          (is-agrupado
            (progn
              (setq txt-final
                (injeta-campos-agrupados txt-safe
                  v-solicitante v-local v-referencias v-apoios)
              )
              (if txt-final
                (progn
                  (setq ed (atualiza-dxf-texto ed txt-final))
                  (entmod ed) (entupd ent)
                )
              )
            )
          )

          ;; ---- FLUXO PADRAO ----
          (T
            (progn
              (setq txt (str-replace "\\P" "\n" (str-replace "\\p" "\n" txt)))
              (setq linhas (str-split txt "\n"))
              (setq nova-txt nil)
              (setq modificado nil)

              (foreach l linhas
                (setq l-limpa (limpa-texto-puro l))
                (setq p-dois  (vl-string-search ":" l-limpa))
                (setq nova-linha l)

                (if (and p-dois (vl-string-search ":" l))
                  (progn
                    (setq l-norm (normaliza-busca l-limpa))
                    (setq campo-achado nil)

                    (foreach f-map
                      '(
                        (("DATA")          "DATA")
                        (("ESCALA")        "ESCALA")
                        (("ALIMENTADOR")   "ALIMENTADOR")
                        (("COMPONENTE")    "COMPONENTE")
                        (("LEVANTAMENTO")  "LEVANTAMENTO")
                        (("DESENHO")       "DESENHO")
                        (("ORCAMENTO")     "ORCAMENTO")
                        (("OS" "DM")       "OS_DM")
                        (("OBRA N")        "OBRA")
                        (("SERVI")         "SERVICO")
                        (("SOLICITANTE")   "SOLICITANTE")
                        (("LOCAL")         "LOCAL")
                        (("REFER")         "REFERENCIAS")
                        (("APOIOS")        "APOIOS")
                        (("GRAU DE RISCO") "GRAU_RISCO")
                        (("REGIONAL")      "REGIONAL")
                      )
                      (if (not campo-achado)
                        (progn
                          (setq match T)
                          (foreach frag (car f-map)
                            (if (not (vl-string-search frag l-norm)) (setq match nil))
                          )
                          (if match (setq campo-achado (cadr f-map)))
                        )
                      )
                    )

                    (if campo-achado
                      (progn
                        (setq valor-campo
                          (cond
                            ((= campo-achado "DATA")         v-data)
                            ((= campo-achado "ESCALA")       v-escala)
                            ((= campo-achado "ALIMENTADOR")  v-alimentador)
                            ((= campo-achado "COMPONENTE")   v-componente)
                            ((= campo-achado "LEVANTAMENTO") v-levantamento)
                            ((= campo-achado "DESENHO")      v-desenho)
                            ((= campo-achado "ORCAMENTO")    v-orcamento)
                            ((= campo-achado "OS_DM")        v-os_dm)
                            ((= campo-achado "OBRA")         v-obra)
                            ((= campo-achado "SERVICO")      v-servico)
                            ((= campo-achado "SOLICITANTE")  v-solicitante)
                            ((= campo-achado "LOCAL")        v-local)
                            ((= campo-achado "REFERENCIAS")  v-referencias)
                            ((= campo-achado "APOIOS")       v-apoios)
                            ((= campo-achado "GRAU_RISCO")   v-grau_risco)
                            ((= campo-achado "REGIONAL")     v-regional)
                            (T "")
                          )
                        )

                        (setq p-real-dois (vl-string-search ":" l))
                        (setq tem-chave (= (substr l (strlen l) 1) "}"))
                        (setq prefixo (substr l 1 (1+ p-real-dois)))

                        (setq suf_folha "")
                        (setq p_f (vl-string-search "FOLHA" (strcase l)))
                        (if p_f
                          (progn
                            (setq suf_folha (substr l (1+ p_f)))
                            (if (= (substr suf_folha (strlen suf_folha) 1) "}")
                              (setq suf_folha (substr suf_folha 1 (1- (strlen suf_folha))))
                            )
                            (setq suf_folha (strcat "    " (vl-string-trim " " suf_folha)))
                          )
                        )

                        (setq nova-linha
                          (strcat prefixo " " valor-campo suf_folha (if tem-chave "}" ""))
                        )
                        (setq modificado T)
                      )
                    )
                  )
                )
                (setq nova-txt (cons nova-linha nova-txt))
              )

              (if modificado
                (progn
                  (setq nova-txt (reverse nova-txt))
                  (setq txt-final (car nova-txt))
                  (foreach item (cdr nova-txt)
                    (setq txt-final (strcat txt-final "\\P" item))
                  )
                  (setq ed (atualiza-dxf-texto ed txt-final))
                  (entmod ed) (entupd ent)
                )
              )
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )

  (princ "\n[CARIMBO] Concluido! Todos os carimbos atualizados.")
  (command "REGEN")
  (princ)
)

(princ "\n[CARIMBO] v15.2 carregado com Sucesso. Execute: CARIMBO\n")
(princ)
;;; EOF