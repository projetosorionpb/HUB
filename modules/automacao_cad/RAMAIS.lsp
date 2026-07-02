;;; ============================================================
;;; RAMAIS.LSP - Gerenciador de Ramais para NanoCAD / AutoCAD
;;; ============================================================
(vl-load-com)

;; Variáveis globais para memória
(if (not *ramais-handles*) (setq *ramais-handles* nil))
(if (not *ramais-mtext-handles*) (setq *ramais-mtext-handles* nil))

;;; ============================================================
;;; ESCRITA DO DCL DINÂMICO
;;; ============================================================
(defun ramais-write-dynamic-dcl (dclpath num-lines / f i)
  (setq f (open dclpath "w"))
  (if (not f) (progn (alert "Erro ao criar DCL temporario na pasta TEMP.") (exit)))

  (write-line "ramais_lista : dialog {" f)
  (write-line "  label = \"Gerenciador de Ramais - Painel Central\"; width = 70;" f)
  (write-line "  : column {" f)
  (write-line "    : list_box { key=\"lst_completa\"; width=66; height=22; multiple_select=false; }" f)
  (write-line "    spacer;" f)
  (write-line "    : button { key=\"btn_ver_ponto\"; label=\"VER / CADASTRAR PONTO\"; alignment=centered; width=40; is_default=true; }" f)
  (write-line "    spacer;" f)
  (write-line "    : row { alignment = centered;" f)
  (write-line "      : button { key=\"btn_gerar_lista\"; label=\"Gerar Novo\"; width=14; }" f)
  (write-line "      : button { key=\"btn_atualizar_mtext\"; label=\"Atualizar Vinculado\"; width=20; }" f)
  (write-line "      : button { key=\"btn_carregar_lista\"; label=\"Carregar\"; width=14; }" f)
  (write-line "      : button { key=\"btn_limpar_lista\"; label=\"Limpar\"; width=14; }" f)
  (write-line "    } spacer; : button { key=\"btn_fechar_lista\"; label=\"Fechar\"; width=16; is_cancel=true; alignment=centered; }" f)
  (write-line "  }" f)
  (write-line "}" f)

  (write-line "ramais_colunas : dialog {" f)
  (write-line "  label = \"Gerar Lista MTEXT\"; width = 36;" f)
  (write-line "  : column {" f)
  (write-line "    : edit_box { key=\"ed_colunas\"; label=\"Numero de colunas:\"; edit_width=6; value=\"1\"; }" f)
  (write-line "    spacer; : row {" f)
  (write-line "      : button { key=\"btn_ok_col\"; label=\"OK\"; width=12; is_default=true; }" f)
  (write-line "      : button { key=\"btn_cancel_col\"; label=\"Cancelar\"; width=12; is_cancel=true; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "}" f)

  (write-line "ramais_confirm : dialog {" f)
  (write-line "  label = \"Confirmacao de Seguranca\"; width = 45;" f)
  (write-line "  : column {" f)
  (write-line "    : text { key = \"txt_conf_msg\"; label = \"\"; alignment = centered; }" f)
  (write-line "    spacer;" f)
  (write-line "    : row { alignment = centered;" f)
  (write-line "      : button { key = \"btn_conf_sim\"; label = \"Sim\"; width = 12; is_default = true; }" f)
  (write-line "      : button { key = \"btn_conf_nao\"; label = \"Nao\"; width = 12; is_cancel = true; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "}" f)

  (write-line "ramais_sync : dialog {" f)
  (write-line "  label = \"Conflito de Sincronizacao\"; width = 50;" f)
  (write-line "  : column {" f)
  (write-line "    : text { label = \"Diferenca detectada entre o arquivo RAMAIS.txt\"; }" f)
  (write-line "    : text { label = \"e o texto MTEXT no desenho.\"; }" f)
  (write-line "    spacer;" f)
  (write-line "    : text { label = \"Qual fonte de dados voce deseja manter?\"; alignment = centered; }" f)
  (write-line "    spacer;" f)
  (write-line "    : row { alignment = centered;" f)
  (write-line "      : button { key = \"btn_sync_txt\"; label = \"Manter RAMAIS.txt\"; width = 20; }" f)
  (write-line "      : button { key = \"btn_sync_mtext\"; label = \"Manter MTEXT\"; width = 20; is_default = true; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "}" f)

  (if (not num-lines) (setq num-lines 8))
  (if (< num-lines 4) (setq num-lines 4))
  
  (write-line "ramais_ponto : dialog {" f)
  (write-line "  label = \"Ramais do Ponto\"; width = 64;" f)
  (write-line "  : column {" f)
  (write-line "    : text { key = \"txt_titulo\"; label = \"Ponto: ---\"; width = 50; } spacer_0;" f)
  
  (write-line "    : row { alignment = centered;" f)
  (write-line "      : button { key=\"btn_q_reinst\"; label=\"REINST. IP-RI\"; }" f)
  (write-line "      : button { key=\"btn_q_rec\"; label=\"REC. CALCADA\"; }" f)
  (write-line "      : button { key=\"btn_q_conc\"; label=\"CONC. BASE\"; }" f)
  (write-line "      : button { key=\"btn_q_comp\"; label=\"COMPRESSOR\"; }" f)
  (write-line "    } spacer_0;" f)

  (write-line "    : boxed_column { label = \"Ramais cadastrados (Junta itens iguais auto)\";" f)
  
  (setq i 1)
  (while (<= i num-lines)
    (write-line (strcat "      : edit_box { key=\"ed_l" (itoa i) "\"; label=\"Linha " (itoa i) ":\"; edit_width=40; }") f)
    (setq i (1+ i))
  )
  
  (write-line "    } spacer; : row {" f)
  (write-line "      : button { key=\"btn_cadastrar\"; label=\"Salvar\"; width=10; is_default=true; }" f)
  (write-line "      : button { key=\"btn_add_linha\"; label=\"Nova Linha\"; width=12; }" f)
  (write-line "      : button { key=\"btn_excluir\"; label=\"Excluir\"; width=10; }" f)
  (write-line "      : button { key=\"btn_cancelar\"; label=\"Cancelar\"; width=10; is_cancel=true; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "}" f)

  (close f)
)

;;; ============================================================
;;; CAMINHOS E ARQUIVOS (Segurança na Memória)
;;; ============================================================
(defun ramais-split-by-comma (str / i ch res cur)
  (setq res nil cur "" i 1)
  (while (<= i (strlen str))
    (setq ch (substr str i 1))
    (if (= ch ",")
      (if (not (= cur "")) (setq res (append res (list cur)) cur ""))
      (setq cur (strcat cur ch))
    )
    (setq i (1+ i))
  )
  (if (not (= cur "")) (setq res (append res (list cur))))
  res
)

(defun ramais-read-file (fp / f ln acc pos hstr temp-h temp-m)
  (setq acc '() temp-h nil temp-m nil)
  (setq f (open fp "r"))
  (if f
    (progn
      (while (setq ln (read-line f))
        (cond
          ((wcmatch ln ";; H:*=*")
           (setq hstr (substr ln 6))
           (setq pos (vl-string-search "=" hstr))
           (if pos
             (setq temp-h (append temp-h (list (cons (atoi (substr hstr 1 pos)) (substr hstr (+ pos 2))))))
           )
          )
          ((wcmatch ln ";; MTEXT_HANDLES=*")
           (setq hstr (substr ln 18))
           (setq temp-m (ramais-split-by-comma hstr))
          )
          ((not (wcmatch ln ";;--- METADATA ---"))
           (setq acc (append acc (list ln)))
          )
        )
      )
      (close f)
      ;; Evita limpar handles por erro de leitura
      (setq *ramais-handles* temp-h)
      (setq *ramais-mtext-handles* temp-m)
    )
  )
  acc
)

(defun ramais-write-file (fp lines / f ln hstr)
  (setq f (open fp "w"))
  (if f
    (progn
      (foreach ln lines (write-line ln f))
      (if (or *ramais-handles* *ramais-mtext-handles*)
        (write-line ";;--- METADATA ---" f)
      )
      (if *ramais-handles*
        (foreach h *ramais-handles*
          (write-line (strcat ";; H:" (itoa (car h)) "=" (cdr h)) f)
        )
      )
      (if *ramais-mtext-handles*
        (progn
          (setq hstr "")
          (foreach h *ramais-mtext-handles* (setq hstr (strcat hstr h ",")))
          (write-line (strcat ";; MTEXT_HANDLES=" hstr) f)
        )
      )
      (close f)
      T
    )
    nil
  )
)

;;; ============================================================
;;; SMART MERGE - LÓGICA DE FUSÃO INTELIGENTE
;;; ============================================================
(defun extract-multiplier (str / base num)
  (setq base str num 1)
  (cond
    ((wcmatch str "* (#X)")
     (setq num (atoi (substr str (- (strlen str) 2) 1)))
     (setq base (r-trim (substr str 1 (- (strlen str) 4))))
    )
    ((wcmatch str "*(#X)")
     (setq num (atoi (substr str (- (strlen str) 2) 1)))
     (setq base (r-trim (substr str 1 (- (strlen str) 3))))
    )
    ((wcmatch str "* (##X)")
     (setq num (atoi (substr str (- (strlen str) 3) 2)))
     (setq base (r-trim (substr str 1 (- (strlen str) 5))))
    )
    ((wcmatch str "*(##X)")
     (setq num (atoi (substr str (- (strlen str) 3) 2)))
     (setq base (r-trim (substr str 1 (- (strlen str) 4))))
    )
  )
  (cons base num)
)

(defun extract-rs-data (str / i ch num-str pre post inside-num)
  (setq i 1 num-str "" pre "" post "" inside-num nil)
  (while (<= i (strlen str))
    (setq ch (substr str i 1))
    (cond
      ((and (>= (ascii ch) 48) (<= (ascii ch) 57))
       (setq inside-num T)
       (setq num-str (strcat num-str ch))
      )
      (inside-num
       (setq post (substr str i))
       (setq i (+ (strlen str) 10)) ; break
      )
      (T (setq pre (strcat pre ch)))
    )
    (setq i (1+ i))
  )
  (if (= num-str "") nil (list pre post (atoi num-str)))
)

(defun ramais-get-line-weight (str / s)
  (setq s (strcase str))
  (cond
    ((wcmatch s "*TROCAR*")
     (cond
       ((wcmatch s "*M AC*") 10)
       ((wcmatch s "*M AM*") 11)
       ((wcmatch s "*M AA*") 12)
       ((wcmatch s "*M SA*") 13)
       ((wcmatch s "*T AM*") 14)
       ((wcmatch s "*T AA*") 15)
       ((wcmatch s "*T SA*") 16)
       (T 19)
     )
    )
    ((or (wcmatch s "*REINST*") (wcmatch s "*RS*"))
     (cond
       ((wcmatch s "*M AC*") 20)
       ((wcmatch s "*M AM*") 21)
       ((wcmatch s "*M SA*") 22)
       ((wcmatch s "*T AM*") 23)
       ((wcmatch s "*T SA*") 24)
       (T 29)
     )
    )
    ((wcmatch s "*IP-RI*") 30)
    ((wcmatch s "*REC*CAL*ADA*") 40)
    ((wcmatch s "*CONC*BASE*") 50)
    (T 100)
  )
)

(defun ramais-sort-lines-by-rules (lines / weighted idx item res)
  (setq weighted '() idx 0)
  (foreach str lines
    (setq weighted (cons (list (ramais-get-line-weight str) idx str) weighted))
    (setq idx (1+ idx))
  )
  (setq weighted (reverse weighted))
  (setq weighted (vl-sort weighted 
    '(lambda (a b) 
       (if (= (car a) (car b))
         (< (cadr a) (cadr b))
         (< (car a) (car b))
       )
     )
  ))
  (setq res '())
  (foreach item weighted
    (setq res (cons (caddr item) res))
  )
  (reverse res)
)

(defun ramais-normalize-spaces (str / out)
  (setq out str)
  (while (vl-string-search "  " out)
    (setq out (vl-string-subst " " "  " out))
  )
  out
)

(defun ramais-smart-merge-lines (lines / result rs-dict ipri-dict others str data key val num match pos res-str num-str)
  (setq rs-dict nil ipri-dict nil others nil)
  (foreach str lines
    (setq str (r-trim (strcase str)))
    (if (not (= str ""))
      (cond
        ((wcmatch str "*RS*")
         (setq data (extract-rs-data str))
         (if data
           (progn
             (setq key (strcat (car data) "<N>" (cadr data)))
             (setq val (caddr data))
             (setq match (assoc key rs-dict))
             (if match
               (setq rs-dict (subst (cons key (+ (cdr match) val)) match rs-dict))
               (setq rs-dict (append rs-dict (list (cons key val))))
             )
           )
           (setq others (append others (list str)))
         )
        )
        ((or (wcmatch str "*IP-RI*") (wcmatch str "*REC*CAL*ADA*"))
         (setq data (extract-multiplier str))
         (setq key (ramais-normalize-spaces (car data)))
         (setq val (cdr data))
         (setq match (assoc key ipri-dict))
         (if match
           (setq ipri-dict (subst (cons key (+ (cdr match) val)) match ipri-dict))
           (setq ipri-dict (append ipri-dict (list (cons key val))))
         )
        )
        (T (setq others (append others (list str))))
      )
    )
  )
  
  (setq result nil)
  (foreach itm others (setq result (append result (list itm))))
  (foreach itm ipri-dict
    (setq key (car itm) num (cdr itm))
    (if (> num 1)
      (setq result (append result (list (strcat key " (" (itoa num) "X)"))))
      (setq result (append result (list key)))
    )
  )
  (foreach itm rs-dict
    (setq key (car itm) num (cdr itm))
    (setq num-str (itoa num))
    (if (< num 10) (setq num-str (strcat "0" num-str)))
    (setq pos (vl-string-search "<N>" key))
    (setq res-str (strcat (substr key 1 pos) num-str (substr key (+ pos 4))))
    (setq result (append result (list res-str)))
  )
  (ramais-sort-lines-by-rules result)
)

;;; ============================================================
;;; UTILITÁRIOS E PARSERS
;;; ============================================================
(defun r-trim (s / out ch)
  (setq out s)
  (while (and (> (strlen out) 0) (or (= (substr out 1 1) " ") (= (substr out 1 1) "\t") (= (substr out 1 1) "\r") (= (substr out 1 1) "\n") (= (ascii (substr out 1 1)) 160))) (setq out (substr out 2)))
  (while (and (> (strlen out) 0) (or (= (substr out (strlen out) 1) " ") (= (substr out (strlen out) 1) "\t") (= (substr out (strlen out) 1) "\r") (= (substr out (strlen out) 1) "\n") (= (ascii (substr out (strlen out) 1)) 160))) (setq out (substr out 1 (1- (strlen out)))))
  out
)

(defun ramais-parse-p-tag (str / pos inner num txt i ch isnum)
  (if (= (substr str 1 2) "(P")
    (progn
      (setq pos (vl-string-position (ascii ")") str))
      (if (and pos (> pos 2))
        (progn
          (setq inner (substr str 3 (- pos 2)))
          (setq isnum T i 1)
          (while (<= i (strlen inner))
            (setq ch (ascii (substr inner i 1)))
            (if (or (< ch 48) (> ch 57)) (setq isnum nil)) 
            (setq i (1+ i))
          )
          (if (and isnum (> (atoi inner) 0)) (list (atoi inner) (r-trim (substr str (+ pos 2)))) nil)
        ) nil
      )
    ) nil
  )
)

(defun ramais-parse-lines (lines / raw-lst cur-num cur-lines str tag-data merged match new-merged final-lst)
  (setq raw-lst nil cur-num nil cur-lines nil)
  (foreach ln lines
    (setq str (r-trim (strcase ln))) 
    (cond
      ((or (= str "") (= (substr str 1 1) ";")) ) 
      ((setq tag-data (ramais-parse-p-tag str))
       (if cur-num (setq raw-lst (append raw-lst (list (cons cur-num cur-lines)))))
       (setq cur-num (car tag-data))
       (if (not (= (cadr tag-data) "")) (setq cur-lines (list (cadr tag-data))) (setq cur-lines nil))
      )
      (cur-num (setq cur-lines (append cur-lines (list str))))
    )
  )
  (if cur-num (setq raw-lst (append raw-lst (list (cons cur-num cur-lines)))))
  
  (setq merged nil)
  (foreach blk raw-lst
    (setq match (assoc (car blk) merged))
    (if match
      (progn
        (setq new-merged nil)
        (foreach m merged
          (if (= (car m) (car blk))
            (setq new-merged (append new-merged (list (cons (car m) (append (cdr m) (cdr blk))))))
            (setq new-merged (append new-merged (list m)))
          )
        )
        (setq merged new-merged)
      )
      (setq merged (append merged (list blk)))
    )
  )

  (setq final-lst nil)
  (foreach blk merged
    (setq final-lst (append final-lst (list (cons (car blk) (ramais-smart-merge-lines (cdr blk))))))
  )
  (vl-sort final-lst '(lambda (a b) (< (car a) (car b))))
)

(defun ramais-parse-file (filepath)
  (ramais-parse-lines (ramais-read-file filepath))
)

;;; ============================================================
;;; FORMATADORES DE ESPAÇO
;;; ============================================================
(defun ramais-format-block (num lines / tag digits spc1 spc2 out first text)
  (setq tag (strcat "(P" (itoa num) ")") digits (strlen (itoa num)) spc1 "  " spc2 "")
  (repeat (+ 7 (* 2 digits)) (setq spc2 (strcat spc2 " ")))
  
  (setq out nil first T)
  (if (or (not lines) (= (length lines) 0))
    (setq out (list tag))
    (foreach text lines
      (setq text (r-trim (strcase text)))
      (if (not (= text ""))
        (progn
          (if first (setq out (append out (list (strcat tag spc1 text)))) (setq out (append out (list (strcat spc2 text)))))
          (setq first nil)
        )
      )
    )
  )
  (if (= (length out) 0) (setq out (list tag)))
  out
)

(defun ramais-format-file-data (lst / out first-blk ln)
  (setq out nil first-blk T)
  (foreach blk lst
    (if (not first-blk) (setq out (append out (list "")))) 
    (setq first-blk nil)
    (foreach ln (ramais-format-block (car blk) (cdr blk)) (setq out (append out (list ln))))
  )
  out
)

(defun ramais-format-block-mtext (num lines / blk-lines chunk sep ln)
  (setq blk-lines (ramais-format-block num lines) chunk "")
  (foreach ln blk-lines (setq sep (if (= chunk "") "" "\\P") chunk (strcat chunk sep ln)))
  chunk
)

;;; ============================================================
;;; EXTRATOR DE MTEXT E CHECAGEM NO DWG
;;; ============================================================
(defun ramais-get-full-mtext (ename / ent txt)
  (setq ent (entget ename) txt "")
  (foreach x ent (if (or (= (car x) 1) (= (car x) 3)) (setq txt (strcat txt (cdr x)))))
  txt
)

(defun ramais-split-mtext (str / i ch res cur)
  (setq res nil cur "" i 1)
  (while (<= i (strlen str))
    (setq ch (substr str i 1))
    (cond
      ((and (= ch "\\") (< i (strlen str)) (or (= (substr str (1+ i) 1) "P") (= (substr str (1+ i) 1) "p")))
       (setq res (append res (list cur)) cur "" i (1+ i)))
      ((= ch "\n") (setq res (append res (list cur)) cur ""))
      ((= ch "\r") ) 
      (T (setq cur (strcat cur ch)))
    )
    (setq i (1+ i))
  )
  (append res (list cur))
)

(defun ramais-set-ponto (lst num new-lines / new-lst found)
  (setq new-lines (vl-remove-if '(lambda (x) (= (r-trim x) "")) (mapcar 'strcase new-lines)))
  (setq new-lst nil found nil)
  (foreach blk lst
    (if (= (car blk) num)
      (progn (setq new-lst (append new-lst (list (cons num new-lines))) found T))
      (setq new-lst (append new-lst (list blk)))
    )
  )
  (if (not found) (setq new-lst (append new-lst (list (cons num new-lines)))))
  (vl-sort new-lst '(lambda (a b) (< (car a) (car b))))
)

(defun ramais-del-ponto (lst num)
  (vl-remove-if '(lambda (blk) (= (car blk) num)) lst)
)

(defun ramais-is-ponto-verde (ename / ent layer-name color txt-raw txt-clean tag-data)
  (setq ent (entget ename))
  (setq layer-name (strcase (cdr (assoc 8 ent))))
  (if (not (= layer-name "FORMATO"))
    nil
    (progn
      (setq color (cdr (assoc 62 ent)))
      (if (and color (not (= color 3)) (not (= color 0)) (not (= color 256)))
        nil
        (progn
          (setq txt-raw (ramais-get-full-mtext ename))
          (setq txt-clean (ramais-strip-mtext-format txt-raw))
          (setq txt-clean (r-trim (strcase txt-clean)))
          (if (> (strlen txt-raw) 200)
            nil
            (ramais-parse-p-tag txt-clean)
          )
        )
      )
    )
  )
)

(defun ramais-strip-mtext-format (str / out i ch skip-until-semi brace-depth)
  (setq out "" i 1 skip-until-semi nil brace-depth 0)
  (while (<= i (strlen str))
    (setq ch (substr str i 1))
    (cond
      (skip-until-semi
       (if (= ch ";") (setq skip-until-semi nil))
      )
      ((= ch "\\")
       (setq i (1+ i))
       (if (<= i (strlen str))
         (progn
           (setq ch (substr str i 1))
           (cond
             ((or (= ch "P") (= ch "p")) (setq out (strcat out " ")))
             ((wcmatch ch "C,F,H,W,T,Q,S,A,c,f,h,w,t,q,s,a") (setq skip-until-semi T))
             ((= ch "~") (setq out (strcat out " ")))
             (T )
           )
         )
       )
      )
      ((= ch "{") (setq brace-depth (1+ brace-depth)))
      ((= ch "}") (if (> brace-depth 0) (setq brace-depth (1- brace-depth))))
      (T (setq out (strcat out ch)))
    )
    (setq i (1+ i))
  )
  (r-trim out)
)

(defun ramais-extract-tag (ename / txt-raw txt-clean tag-data)
  (setq txt-raw (ramais-get-full-mtext ename))
  (setq txt-clean (r-trim (strcase (ramais-strip-mtext-format txt-raw))))
  (setq tag-data (ramais-parse-p-tag txt-clean))
  (if tag-data (strcat "(P" (itoa (car tag-data)) ")") nil)
)

(defun ramais-get-all-pontos-verdes ( / ss i ename tag-data result num)
  (setq result nil)
  (setq ss (ssget "X" '((0 . "TEXT,MTEXT") (8 . "FORMATO"))))
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ename (ssname ss i))
        (setq tag-data (ramais-is-ponto-verde ename))
        (if tag-data
          (progn
            (setq num (car tag-data))
            (if (not (assoc num result))
              (setq result (append result (list (cons num ename))))
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )
  result
)

(defun ramais-check-ponto-verde (num / pontos match)
  (setq pontos (ramais-get-all-pontos-verdes))
  (setq match (assoc num pontos))
  (if match (cdr match) nil)
)

(defun ramais-auto-sync-pontos (lst filepath / new-lst synced hmatch ename tag-str new-tag new-num num blk pontos-verdes pv-match updated-handles)
  (setq new-lst nil synced nil)
  (setq pontos-verdes (ramais-get-all-pontos-verdes))
  (setq updated-handles *ramais-handles*)

  (foreach blk lst
    (setq num (car blk))
    (setq hmatch (assoc num updated-handles))
    
    (if hmatch
      (progn
        (setq ename (handent (cdr hmatch)))
        (if (and ename (entget ename))
          (progn
            (setq tag-str (ramais-extract-tag ename))
            (if (and tag-str (not (= tag-str (strcat "(P" (itoa num) ")"))))
              (progn
                (setq new-tag (ramais-parse-p-tag (strcase tag-str)))
                (if new-tag
                  (progn
                    (setq new-num (car new-tag))
                    (princ (strcat "\n[RAMAIS] Ponto (P" (itoa num) ") renomeado para (P" (itoa new-num) ") automaticamente!"))
                    (setq updated-handles (vl-remove-if '(lambda (h) (= (car h) num)) updated-handles))
                    (setq updated-handles (append updated-handles (list (cons new-num (cdr hmatch)))))
                    (setq num new-num)
                    (setq synced T)
                  )
                )
              )
            )
          )
          (setq updated-handles (vl-remove-if '(lambda (h) (= (car h) num)) updated-handles))
        )
        (setq new-lst (append new-lst (list (cons num (cdr blk)))))
      )
      (progn
        (setq pv-match (assoc num pontos-verdes))
        (if pv-match
          (progn
            (setq updated-handles (append updated-handles (list (cons num (cdr (assoc 5 (entget (cdr pv-match))))))))
            (princ (strcat "\n[RAMAIS] Ponto (P" (itoa num) ") vinculado ao objeto verde no DWG."))
          )
        )
        (setq new-lst (append new-lst (list (cons num (cdr blk)))))
      )
    )
  )

  (setq *ramais-handles* updated-handles)

  (if synced
    (progn (setq new-lst (vl-sort new-lst '(lambda (a b) (< (car a) (car b))))) new-lst)
    lst
  )
)

;;; ============================================================
;;; DIÁLOGOS
;;; ============================================================
(defun ramais-dlg-confirm (msg / dclpath dcl-id key)
  (setq dclpath (strcat (getvar "TEMPPREFIX") "RAMAIS_TEMP.dcl"))
  (setq dcl-id (load_dialog dclpath))
  (if (new_dialog "ramais_confirm" dcl-id)
    (progn
      (set_tile "txt_conf_msg" msg)
      (action_tile "btn_conf_sim" "(done_dialog 1)")
      (action_tile "btn_conf_nao" "(done_dialog 0)")
      (setq key (start_dialog))
      (unload_dialog dcl-id)
      (= key 1)
    )
    (progn (unload_dialog dcl-id) nil)
  )
)

(defun ramais-dlg-sync-conflict (dclpath / dcl-id key)
  (setq dcl-id (load_dialog dclpath))
  (if (new_dialog "ramais_sync" dcl-id)
    (progn
      (action_tile "btn_sync_txt" "(done_dialog 1)")
      (action_tile "btn_sync_mtext" "(done_dialog 2)")
      (setq key (start_dialog))
      (unload_dialog dcl-id)
      key
    )
    2
  )
)

(defun ramais-dlg-ponto (num filepath lst / dclpath dcl-id key match campos i val _new_lines updated lines-count loop_pt action_str dwg-ename hmatch insert-quick-text)
  (setq match (assoc num lst))
  (setq campos (if match (cdr match) '()))
  
  (setq campos (vl-remove-if '(lambda (x) (= (r-trim x) "")) campos))
  (if (< (length campos) 8) (setq campos (append campos (list "" "" "" "" "" "" "" ""))))
  (setq lines-count (length campos))
  
  (setq loop_pt T)
  (while loop_pt
    (setq dclpath (strcat (getvar "TEMPPREFIX") "RAMAIS_TEMP.dcl"))
    (if (findfile dclpath) (vl-file-delete dclpath))
    (ramais-write-dynamic-dcl dclpath lines-count)
    
    (setq dcl-id (load_dialog dclpath))
    (new_dialog "ramais_ponto" dcl-id)
    (set_tile "txt_titulo" (strcat "Ponto: (P" (itoa num) ")"))
    
    (defun insert-quick-text (txt / j found v)
      (setq j 1 found nil)
      (while (and (<= j lines-count) (not found))
        (setq v (get_tile (strcat "ed_l" (itoa j))))
        (if (= (r-trim v) "")
          (progn
            (set_tile (strcat "ed_l" (itoa j)) txt)
            (setq found T)
          )
        )
        (setq j (1+ j))
      )
    )
    
    (action_tile "btn_q_reinst" "(insert-quick-text \"REINST. IP-RI\")")
    (action_tile "btn_q_rec"    (strcat "(insert-quick-text \"REC. CAL" (chr 199) "ADA\")"))
    (action_tile "btn_q_conc"   "(insert-quick-text \"CONC. BASE\")")
    (action_tile "btn_q_comp"   "(insert-quick-text \"USO DE COMPRESSOR\")")

    (setq i 1)
    (foreach val campos (set_tile (strcat "ed_l" (itoa i)) val) (setq i (1+ i)))
    
    (setq action_str "(progn (setq _new_lines nil) ")
    (setq i 1)
    (while (<= i lines-count)
      (setq action_str (strcat action_str "(setq _new_lines (append _new_lines (list (get_tile \"ed_l" (itoa i) "\")))) "))
      (setq i (1+ i))
    )
    
    (action_tile "btn_cadastrar" (strcat action_str " (done_dialog 1))"))
    (action_tile "btn_add_linha" (strcat action_str " (done_dialog 4))"))
    (action_tile "btn_excluir" "(done_dialog 2)")
    (action_tile "btn_cancelar" "(done_dialog 0)")
    
    (setq key (start_dialog))
    (unload_dialog dcl-id)
    
    (cond
      ((= key 1) 
       (setq dwg-ename (ramais-check-ponto-verde num))
       
       (if (not dwg-ename)
         (if (ramais-dlg-confirm (strcat "ATENCAO: Ponto (P" (itoa num) ") nao encontrado\nna layer FORMATO com cor verde.\nDeseja cadastrar mesmo assim?"))
           (progn
             (setq loop_pt nil _new_lines (ramais-smart-merge-lines _new_lines))
             (setq updated (ramais-set-ponto lst num _new_lines))
             (ramais-write-file filepath (ramais-format-file-data updated))
             (ramais-silent-update-mtext updated)
             (princ (strcat "\nPonto (P" (itoa num) ") salvo SEM vinculo no DWG."))
             (setq lst updated)
           )
           (setq loop_pt T)
         )
         (progn
           (setq loop_pt nil _new_lines (ramais-smart-merge-lines _new_lines))
           (setq updated (ramais-set-ponto lst num _new_lines))
           (setq hmatch (assoc num *ramais-handles*))
           (if hmatch
             (setq *ramais-handles* (subst (cons num (cdr (assoc 5 (entget dwg-ename)))) hmatch *ramais-handles*))
             (setq *ramais-handles* (append *ramais-handles* (list (cons num (cdr (assoc 5 (entget dwg-ename)))))))
           )
           (ramais-write-file filepath (ramais-format-file-data updated))
           (ramais-silent-update-mtext updated)
           (princ (strcat "\nPonto (P" (itoa num) ") salvo e vinculado."))
           (setq lst updated)
         )
       )
      )
      ((= key 4) 
       (setq campos (append _new_lines (list "")))
       (setq lines-count (length campos))
      )
      ((= key 2) 
       (if (ramais-dlg-confirm (strcat "Deseja realmente EXCLUIR o ponto (P" (itoa num) ")?"))
         (progn
           (setq loop_pt nil updated (ramais-del-ponto lst num))
           (setq *ramais-handles* (vl-remove-if '(lambda (h) (= (car h) num)) *ramais-handles*))
           (ramais-write-file filepath (ramais-format-file-data updated))
           (ramais-silent-update-mtext updated)
           (princ (strcat "\nPonto (P" (itoa num) ") EXCLUIDO com sucesso."))
           (setq lst updated)
         )
         (setq loop_pt T) 
       )
      )
      (T (setq loop_pt nil))
    )
  )
  lst
)

(defun ramais-dlg-lista (dclpath filepath / dcl-id key lines ln)
  (setq dcl-id (load_dialog dclpath))
  (new_dialog "ramais_lista" dcl-id)
  
  (setq lines (ramais-read-file filepath))
  (start_list "lst_completa")
  (if (or (not lines) (= (length lines) 0))
    (add_list "  << Arquivo vazio >>")
    (foreach ln lines (add_list ln))
  )
  (end_list)
  
  (action_tile "btn_ver_ponto"       "(done_dialog 1)")
  (action_tile "btn_gerar_lista"     "(done_dialog 4)")
  (action_tile "btn_atualizar_mtext" "(done_dialog 6)")
  (action_tile "btn_carregar_lista"  "(done_dialog 3)")
  (action_tile "btn_limpar_lista"    "(done_dialog 2)")
  (action_tile "btn_fechar_lista"    "(done_dialog 0)")
  
  (setq key (start_dialog))
  (unload_dialog dcl-id)
  
  (if (= key 2)
    (if (ramais-dlg-confirm "Deseja realmente LIMPAR TODA A LISTA de ramais?")
      (progn 
        (ramais-write-file filepath '())
        (ramais-silent-update-mtext '())
        (princ "\nTodos os ramais foram excluidos com sucesso.")
        5
      )
      5
    )
    key
  )
)

(defun ramais-dlg-colunas (dclpath / dcl-id key ncol)
  (setq dcl-id (load_dialog dclpath))
  (new_dialog "ramais_colunas" dcl-id)
  (set_tile "ed_colunas" "1")
  (action_tile "btn_ok_col" "(progn (setq _ncol_raw (get_tile \"ed_colunas\")) (done_dialog 1))")
  (action_tile "btn_cancel_col" "(done_dialog 0)")
  (setq key (start_dialog))
  (unload_dialog dcl-id)
  (if (= key 1) (progn (setq ncol (atoi _ncol_raw)) (if (< ncol 1) (setq ncol 1)) ncol) nil)
)

;;; ============================================================
;;; GERAR E ATUALIZAR MTEXT NO DESENHO
;;; ============================================================
(defun ramais-gerar-mtext (lst ncol / total ipc col-texts i ci blk chunk sep pt larg ins-pt ct)
  (if (= (length lst) 0)
    (alert "Nenhum ponto cadastrado para gerar.")
    (progn
      (setq total (length lst) ipc (/ (+ total ncol -1) ncol) col-texts '() i 0)
      
      (repeat ncol
        (setq chunk "" ci 0)
        (while (and (< ci ipc) (< i total))
          (setq blk (nth i lst))
          (setq sep (if (= chunk "") "" "\\P\\P"))
          (setq chunk (strcat chunk sep (ramais-format-block-mtext (car blk) (cdr blk))))
          (setq ci (1+ ci) i (1+ i))
        )
        (if (not (= chunk "")) (setq col-texts (append col-texts (list chunk))))
      )
      
      (setq pt (getpoint "\nClique no ponto de insercao do MTEXT: "))
      (if pt
        (progn
          (if (not (tblsearch "LAYER" "RAMAL"))
            (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord") '(100 . "AcDbLayerTableRecord") '(2 . "RAMAL") '(70 . 0) '(62 . 7)))
          )
          
          (setq *ramais-mtext-handles* nil larg 60.0 i 0)
          (foreach ct col-texts
            (setq ins-pt (list (+ (car pt) (* i larg)) (cadr pt) (caddr pt)))
            (entmake (list (cons 0 "MTEXT") (cons 100 "AcDbEntity") (cons 8 "RAMAL") (cons 62 7) (cons 100 "AcDbMText") (cons 10 ins-pt) (cons 40 1.5) (cons 41 larg) (cons 71 1) (cons 1 ct)))
            (setq *ramais-mtext-handles* (append *ramais-mtext-handles* (list (cdr (assoc 5 (entget (entlast)))))))
            (setq i (1+ i))
          )
          (princ (strcat "\n" (itoa (length col-texts)) " coluna(s) gerada(s) com sucesso."))
        )
      )
    )
  )
)

(defun ramais-silent-update-mtext (lst / ncol total ipc col-texts chunk sep blk i ci ename obj h valid-handles)
  (if *ramais-mtext-handles*
    (progn
      (setq valid-handles nil)
      (foreach h *ramais-mtext-handles*
        (if (and (handent h) (entget (handent h))) (setq valid-handles (append valid-handles (list h))))
      )
      (setq *ramais-mtext-handles* valid-handles)
      
      (if (> (length *ramais-mtext-handles*) 0)
        (if (= (length lst) 0)
          (foreach h *ramais-mtext-handles* (vla-put-TextString (vlax-ename->vla-object (handent h)) " "))
          (progn
            (setq ncol (length *ramais-mtext-handles*))
            (setq total (length lst) ipc (/ (+ total ncol -1) ncol) col-texts '() i 0)
            
            (repeat ncol
              (setq chunk "" ci 0)
              (while (and (< ci ipc) (< i total))
                (setq blk (nth i lst))
                (setq sep (if (= chunk "") "" "\\P\\P"))
                (setq chunk (strcat chunk sep (ramais-format-block-mtext (car blk) (cdr blk))))
                (setq ci (1+ ci) i (1+ i))
              )
              (setq col-texts (append col-texts (list chunk)))
            )
            
            (setq i 0)
            (foreach h *ramais-mtext-handles*
              (setq ename (handent h))
              (vla-put-TextString (vlax-ename->vla-object ename) (nth i col-texts))
              (setq i (1+ i))
            )
          )
        )
      )
    )
  )
)

(defun ramais-atualizar-mtext-vinculado (lst)
  (if (= (length lst) 0)
    (alert "Nenhum ponto cadastrado para atualizar.")
    (if (not *ramais-mtext-handles*)
      (alert "Nenhum MTEXT vinculado.\nUse a opcao 'Gerar Novo' ou 'Carregar' primeiro.")
      (progn
        (ramais-silent-update-mtext lst)
        (princ "\nLista atualizada em todos os MTEXTs vinculados.")
      )
    )
  )
)

;;; ============================================================
;;; COMANDO PRINCIPAL
;;; ============================================================
(defun C:RAMAIS ( / dclpath txtpath lst-txt lst-mtext lst key ss ename tag num ncol loop all-lines i txt res synced-lst hmatch sync-choice valid-handles)
  (setq txtpath (getvar "DWGPREFIX"))
  (if (or (not txtpath) (= txtpath ""))
    (progn (alert "ATENCAO:\n\nO desenho atual ainda nao foi salvo!\nSalve o desenho primeiro para criar o arquivo RAMAIS.txt.") (princ "\nCancelado."))
    (progn
      (setq txtpath (strcat txtpath "RAMAIS.txt"))
      (if (not (findfile txtpath)) (ramais-write-file txtpath '()))
      
      ;; 1. Carrega TXT Primário
      (setq lst-txt (ramais-parse-file txtpath))
      (setq lst lst-txt)
      
      ;; Prepara DCL Base
      (setq dclpath (strcat (getvar "TEMPPREFIX") "RAMAIS_TEMP.dcl"))
      (if (findfile dclpath) (vl-file-delete dclpath))
      (ramais-write-dynamic-dcl dclpath 8)
      
      ;; 2. Verifica se o MTEXT foi editado manualmente
      (if *ramais-mtext-handles*
        (progn
          (setq all-lines nil valid-handles nil)
          (foreach h *ramais-mtext-handles*
            (setq ename (handent h))
            (if (and ename (entget ename))
              (progn
                (setq valid-handles (append valid-handles (list h)))
                (setq txt (ramais-get-full-mtext ename))
                (setq all-lines (append all-lines (ramais-split-mtext txt)))
              )
            )
          )
          (setq *ramais-mtext-handles* valid-handles)
          
          (if all-lines
            (progn
              (setq lst-mtext (ramais-parse-lines all-lines))
              ;; Se houver diferença, aciona o mediador de conflitos
              (if (not (equal lst-txt lst-mtext))
                (progn
                  (setq sync-choice (ramais-dlg-sync-conflict dclpath))
                  (if (= sync-choice 2)
                    (progn 
                      (setq lst lst-mtext)
                      (princ "\n[RAMAIS] Sincronizado a partir do MTEXT.")
                    )
                    (progn 
                      (setq lst lst-txt)
                      (ramais-silent-update-mtext lst)
                      (princ "\n[RAMAIS] Sincronizado a partir do RAMAIS.txt.")
                    )
                  )
                )
              )
            )
          )
        )
      )
      
      ;; 3. Sincronização de renomeação de pontos verdes no DWG
      (setq synced-lst (ramais-auto-sync-pontos lst txtpath))
      (if (not (equal synced-lst lst))
        (progn
          (setq lst synced-lst)
          (princ "\n[RAMAIS] Vinculos de pontos sincronizados.")
        )
      )
      
      ;; Atualiza o TXT para refletir qualquer escolha feita na abertura
      (ramais-write-file txtpath (ramais-format-file-data lst))
      
      ;; Loop Principal do DCL
      (setq loop T)
      (while loop
        (setq lst (ramais-parse-file txtpath))
        (setq key (ramais-dlg-lista dclpath txtpath))

        (cond
          ((= key 1)
           (initget 128)
           (setq res (getpoint "\nSelecione o texto verde (P#) na layer FORMATO ou digite o numero: "))
           (cond
             ((= (type res) 'STR)
              (setq num (atoi res))
              (if (> num 0) (setq lst (ramais-dlg-ponto num txtpath lst)) (alert "Numero de ponto invalido."))
             )
             ((= (type res) 'LIST)
              (setq ss (ssget res '((0 . "TEXT,MTEXT"))))
              (if ss
                (progn
                  (setq ename (ssname ss 0) tag (ramais-extract-tag ename))
                  (if tag
                    (progn
                      (setq num (car (ramais-parse-p-tag (strcase tag))))
                      (if num
                        (progn
                          (setq hmatch (assoc num *ramais-handles*))
                          (if hmatch
                            (setq *ramais-handles* (subst (cons num (cdr (assoc 5 (entget ename)))) hmatch *ramais-handles*))
                            (setq *ramais-handles* (append *ramais-handles* (list (cons num (cdr (assoc 5 (entget ename)))))))
                          )
                          (setq lst (ramais-dlg-ponto num txtpath lst))
                        )
                        (alert "Tag (P#) invalida no objeto selecionado.")
                      )
                    )
                    (alert "Nenhum padrao (P#) valido encontrado no objeto selecionado.")
                  )
                )
                (alert "Nenhum TEXT/MTEXT encontrado sob o clique.")
              )
             )
           )
          )
          ((= key 3)
           (princ "\nSelecione um ou mais MTEXT para carregar a lista: ")
           (setq ss (ssget '((0 . "MTEXT"))))
           (if ss
             (progn
               (setq *ramais-mtext-handles* nil all-lines nil i 0)
               (while (< i (sslength ss))
                 (setq ename (ssname ss i))
                 (setq *ramais-mtext-handles* (append *ramais-mtext-handles* (list (cdr (assoc 5 (entget ename))))))
                 (setq txt (ramais-get-full-mtext ename))
                 (setq all-lines (append all-lines (ramais-split-mtext txt)))
                 (setq i (1+ i))
               )
               (setq lst (ramais-parse-lines all-lines))
               (ramais-write-file txtpath (ramais-format-file-data lst))
               (princ (strcat "\nForam carregados e unificados " (itoa (length lst)) " pontos a partir dos MTEXTs!"))
             )
             (princ "\nNenhum MTEXT foi selecionado.")
           )
          )
          ((= key 4)
           (setq ncol (ramais-dlg-colunas dclpath))
           (if ncol (progn (ramais-gerar-mtext lst ncol) (ramais-write-file txtpath (ramais-format-file-data lst))))
          )
          ((= key 6) (ramais-atualizar-mtext-vinculado lst))
          ((= key 5) ) ;; Retorno limpo
          (T (setq loop nil))
        )
      )
      
      ;; 4. Prompt de Saída (Verifica se precisa gerar MTEXT antes de fechar)
      (if (and (not *ramais-mtext-handles*) (> (length lst) 0))
        (if (ramais-dlg-confirm "A lista possui itens, mas nenhum MTEXT foi gerado no desenho.\nDeseja gerar o MTEXT agora?")
          (progn
            (setq ncol (ramais-dlg-colunas dclpath))
            (if ncol (progn (ramais-gerar-mtext lst ncol) (ramais-write-file txtpath (ramais-format-file-data lst))))
          )
        )
      )

      (if (findfile dclpath) (vl-file-delete dclpath))
      (princ "\nComando RAMAIS encerrado.")
    )
  )
  (princ)
)

(princ "\nRAMAIS.LSP carregado (Sync Bidirecional Inteligente). Digite RAMAIS para iniciar.")
(princ)