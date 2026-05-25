;;; ============================================================
;;; RAMAIS.LSP - Gerenciador de Ramais para NanoCAD / AutoCAD
;;; ============================================================
(vl-load-com)

;;; ============================================================
;;; ESCRITA DO DCL DINÂMICO (Adaptável ao número de linhas)
;;; ============================================================
(defun ramais-write-dynamic-dcl (dclpath num-lines / f i)
  (setq f (open dclpath "w"))
  (if (not f) (progn (alert "Erro ao criar DCL temporario na pasta TEMP.") (exit)))

  (write-line "ramais_menu : dialog {" f)
  (write-line "  label = \"RAMAIS - Gerenciador de Ramais\"; width = 42;" f)
  (write-line "  : column {" f)
  (write-line "    : boxed_column { label = \"Opcoes\";" f)
  (write-line "      : button { key = \"btn_ver_ponto\"; label = \"VER / CADASTRAR PONTO\"; width = 32; }" f)
  (write-line "      spacer_0;" f)
  (write-line "      : button { key = \"btn_ver_lista\"; label = \"VER LISTA COMPLETA\"; width = 32; }" f)
  (write-line "      spacer_0;" f)
  (write-line "      : button { key = \"btn_gerar\"; label = \"GERAR LISTA (MTEXT)\"; width = 32; }" f)
  (write-line "    } spacer; : button { key = \"btn_fechar\"; label = \"Fechar\"; width = 14; is_cancel = true; alignment = centered; }" f)
  (write-line "  }" f)
  (write-line "}" f)

  (write-line "ramais_lista : dialog {" f)
  (write-line "  label = \"Lista Completa de Ramais\"; width = 64;" f)
  (write-line "  : column {" f)
  (write-line "    : list_box { key=\"lst_completa\"; width=60; height=22; multiple_select=false; }" f)
  (write-line "    spacer; : row { alignment = centered;" f)
  (write-line "      : button { key=\"btn_carregar_lista\"; label=\"Carregar MTEXT\"; width=16; }" f)
  (write-line "      : button { key=\"btn_limpar_lista\"; label=\"Limpar Lista\"; width=16; }" f)
  (write-line "      : button { key=\"btn_fechar_lista\"; label=\"Fechar\"; width=16; is_cancel=true; }" f)
  (write-line "    }" f)
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

  ;; DIÁLOGO DE CONFIRMAÇÃO DE SEGURANÇA
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

  ;; DIÁLOGO DO PONTO É GERADO DINAMICAMENTE
  (if (not num-lines) (setq num-lines 8))
  (if (< num-lines 4) (setq num-lines 4))
  
  (write-line "ramais_ponto : dialog {" f)
  (write-line "  label = \"Ramais do Ponto\"; width = 56;" f)
  (write-line "  : column {" f)
  (write-line "    : text { key = \"txt_titulo\"; label = \"Ponto: ---\"; width = 50; } spacer_0;" f)
  (write-line "    : boxed_column { label = \"Ramais cadastrados (Junta itens iguais auto)\";" f)
  
  ;; Loop que cria a quantidade exata de linhas necessárias
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
;;; CAMINHOS E ARQUIVOS 
;;; ============================================================
(defun ramais-read-file (fp / f ln acc)
  (setq acc '())
  (setq f (open fp "r"))
  (if f (progn (while (setq ln (read-line f)) (setq acc (append acc (list ln)))) (close f)))
  acc
)

(defun ramais-write-file (fp lines / f ln)
  (setq f (open fp "w"))
  (if f (progn (foreach ln lines (write-line ln f)) (close f) T) nil)
)

;;; ============================================================
;;; SMART MERGE - LÓGICA DE FUSÃO INTELIGENTE E ORDENAÇÃO CUSTOM
;;; ============================================================

;; Extrai e conta o multiplicador (ex: "(2X)") do fim do texto
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

;; Isola o numero de uma string contendo "RS"
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

;; Define pesos hierárquicos para a ordenação personalizada das linhas
(defun ramais-get-line-weight (str / s)
  (setq s (strcase str))
  (cond
    ;; 1. Linhas que contém TROCAR
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
    ;; 2. Linhas que contém REINST e RS
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
    ;; 3. Linhas que contém IP-RI
    ((wcmatch s "*IP-RI*") 30)
    ;; 4. Linhas que contém REC*CAL*ADA
    ((wcmatch s "*REC*CAL*ADA*") 40)
    ;; 5. Linhas que contém CONC*BASE
    ((wcmatch s "*CONC*BASE*") 50)
    ;; Outros (Garante estabilidade para textos não mapeados)
    (T 100)
  )
)

;; Executa a ordenação estável baseada nas regras de negócio informadas
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
         (< (cadr a) (cadr b)) ;; Se o subgrupo for igual, mantém a ordem original digitada
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

;; Remove múltiplos espaços internos para garantir a fusão perfeita de textos com pequenos erros de digitação
(defun ramais-normalize-spaces (str / out)
  (setq out str)
  (while (vl-string-search "  " out)
    (setq out (vl-string-subst " " "  " out))
  )
  out
)

;; Motor Central de Fusão de Linhas
(defun ramais-smart-merge-lines (lines / result rs-dict ipri-dict others str data key val num match pos res-str num-str)
  (setq rs-dict nil ipri-dict nil others nil)
  (foreach str lines
    (setq str (r-trim (strcase str)))
    (if (not (= str ""))
      (cond
        ;; REGRA 1: Contém RS (Soma números)
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
        ;; REGRA 2: Contém IP-RI ou REC*CAL*ADA (Agrupa, limpa espaços duplicados e soma os multiplicadores X)
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
        ;; REGRA 3: Demais linhas (Mantém intactas)
        (T (setq others (append others (list str))))
      )
    )
  )
  
  ;; Reconstrói a lista formatada
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
  
  ;; Aplica a ordenação customizada solicitada antes de retornar o bloco de linhas
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
  
  ;; Unifica P# Duplicados
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

  ;; Aplica Smart Merge nas linhas e Ordena
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
;;; EXTRATOR DE MTEXT E ATUALIZAÇÕES
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

(defun ramais-extract-tag (ename / txt i ch depth acc tag)
  (setq txt (ramais-get-full-mtext ename) i 1 depth 0 acc "" tag nil)
  (while (and (<= i (strlen txt)) (not tag))
    (setq ch (substr txt i 1))
    (cond
      ((= ch "(") (setq acc "(" depth 1))
      ((and (= depth 1) (= ch ")"))
       (setq acc (strcat acc ")"))
       (if (ramais-parse-p-tag acc) (setq tag acc))
       (setq depth 0 acc ""))
      ((= depth 1) (setq acc (strcat acc ch)))
    )
    (setq i (1+ i))
  )
  tag
)

;;; ============================================================
;;; DIÁLOGOS
;;; ============================================================
(defun ramais-dlg-main (dclpath / dcl-id key)
  (setq dcl-id (load_dialog dclpath))
  (new_dialog "ramais_menu" dcl-id)
  (action_tile "btn_ver_ponto" "(done_dialog 1)")
  (action_tile "btn_ver_lista" "(done_dialog 2)")
  (action_tile "btn_gerar"     "(done_dialog 3)")
  (action_tile "btn_fechar"    "(done_dialog 0)")
  (setq key (start_dialog))
  (unload_dialog dcl-id)
  key
)

;; Função auxiliar para chamar a caixa de confirmação Sim/Não
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

(defun ramais-dlg-ponto (num filepath lst / dclpath dcl-id key match campos i val _new_lines updated lines-count loop_pt action_str)
  (setq match (assoc num lst))
  (setq campos (if match (cdr match) '()))
  
  ;; Conta as linhas reais e garante pelo menos 8 na interface inicial
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
      ((= key 1) ;; SALVAR
       (setq loop_pt nil)
       (setq _new_lines (ramais-smart-merge-lines _new_lines))
       (setq updated (ramais-set-ponto lst num _new_lines))
       (ramais-write-file filepath (ramais-format-file-data updated))
       (princ (strcat "\nPonto (P" (itoa num) ") salvo com sucesso."))
      )
      ((= key 4) ;; NOVA LINHA
       (setq campos (append _new_lines (list "")))
       (setq lines-count (length campos))
      )
      ((= key 2) ;; EXCLUIR (Com confirmação)
       (if (ramais-dlg-confirm (strcat "Deseja realmente EXCLUIR o ponto (P" (itoa num) ")?"))
         (progn
           (setq loop_pt nil)
           (setq updated (ramais-del-ponto lst num))
           (ramais-write-file filepath (ramais-format-file-data updated))
           (princ (strcat "\nPonto (P" (itoa num) ") EXCLUIDO com sucesso."))
         )
         (setq loop_pt T) ;; Se cancelar, mantém a janela do ponto aberta
       )
      )
      (T (setq loop_pt nil))
    )
  )
)

(defun ramais-dlg-lista (dclpath filepath / dcl-id lines ln key)
  (setq dcl-id (load_dialog dclpath))
  (new_dialog "ramais_lista" dcl-id)
  (setq lines (ramais-read-file filepath))
  (if (= (length lines) 0) (setq lines (list "  << Arquivo vazio >>")))
  (start_list "lst_completa")
  (foreach ln lines (add_list ln))
  (end_list)
  
  (action_tile "btn_carregar_lista" "(done_dialog 3)")
  (action_tile "btn_limpar_lista" "(done_dialog 2)")
  (action_tile "btn_fechar_lista" "(done_dialog 0)")
  
  (setq key (start_dialog))
  (unload_dialog dcl-id)
  
  (if (= key 2) ;; LIMPAR LISTA COMPLETA (Com confirmação)
    (if (ramais-dlg-confirm "Deseja realmente LIMPAR TODA A LISTA de ramais?")
      (progn (ramais-write-file filepath '()) (princ "\nTodos os ramais foram excluuidos com sucesso.") 2)
      0
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
;;; GERAR MTEXT NO DESENHO
;;; ============================================================
(defun ramais-gerar-mtext (lst ncol / total ipc col-texts i ci blk chunk sep pt larg ins-pt ct)
  (if (= (length lst) 0) (progn (alert "Nenhum ponto cadastrado.") (exit)))
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
  (if (not pt) (exit))
  
  ;; MELHORIA AQUI: Criação nativa e limpa da camada por entmake (Evita o bug do comando CIRCLE)
  (if (not (tblsearch "LAYER" "RAMAL"))
    (entmake (list
               '(0 . "LAYER")
               '(100 . "AcDbSymbolTableRecord")
               '(100 . "AcDbLayerTableRecord")
               '(2 . "RAMAL")
               '(70 . 0)
               '(62 . 7)
             ))
  )
  
  (setq larg 60.0 i 0)
  (foreach ct col-texts
    (setq ins-pt (list (+ (car pt) (* i larg)) (cadr pt) (caddr pt)))
    (entmake
      (list (cons 0 "MTEXT") (cons 100 "AcDbEntity") (cons 8 "RAMAL") (cons 62 7) (cons 100 "AcDbMText") (cons 10 ins-pt) (cons 40 1.5) (cons 41 larg) (cons 71 1) (cons 1 ct))
    )
    (setq i (1+ i))
  )
  (princ (strcat "\n" (itoa (length col-texts)) " coluna(s) gerada(s) com sucesso."))
)

;;; ============================================================
;;; COMANDO PRINCIPAL
;;; ============================================================
(defun C:RAMAIS ( / dclpath txtpath lst key subkey ss ename tag num ncol loop all-lines i txt res)
  (setq txtpath (getvar "DWGPREFIX"))
  (if (or (not txtpath) (= txtpath ""))
    (progn (alert "ATENCAO:\n\nO desenho atual ainda nao foi salvo!\nSalve o desenho primeiro para criar o arquivo RAMAIS.txt.") (princ "\nCancelado."))
    (progn
      (setq txtpath (strcat txtpath "RAMAIS.txt"))
      (if (not (findfile txtpath)) (ramais-write-file txtpath '()))
      (setq loop T)
      
      (while loop
        (setq dclpath (strcat (getvar "TEMPPREFIX") "RAMAIS_TEMP.dcl"))
        (if (findfile dclpath) (vl-file-delete dclpath))
        (ramais-write-dynamic-dcl dclpath 8)

        (setq lst (ramais-parse-file txtpath))
        (ramais-write-file txtpath (ramais-format-file-data lst))

        (setq key (ramais-dlg-main dclpath))

        (cond
          ((= key 1)
           (initget 128)
           (setq res (getpoint "\nSelecione o MTEXT do ponto (P#) ou digite o numero: "))
           (cond
             ;; Cenário A: O usuário digitou um número diretamente
             ((= (type res) 'STR)
              (setq num (atoi res))
              (if (> num 0)
                (ramais-dlg-ponto num txtpath lst)
                (alert "Numero de ponto invalido.")
              )
             )
             ;; Cenário B: O usuário clicou em um objeto na tela
             ((= (type res) 'LIST)
              (setq ss (ssget res '((0 . "MTEXT"))))
              (if ss
                (progn
                  (setq ename (ssname ss 0))
                  (setq tag (ramais-extract-tag ename))
                  (if tag
                    (progn
                      (setq num (atoi (substr tag 3 (- (strlen tag) 3))))
                      ;; Abre o Formulario do Ponto
                      (ramais-dlg-ponto num txtpath lst)
                    )
                    (alert "Nenhum padrao (P#) valido encontrado.")
                  )
                )
                (alert "Nenhum MTEXT valido selecionado sob o clique.")
              )
             )
           )
          )
          ((= key 2) 
           (setq subkey (ramais-dlg-lista dclpath txtpath))
           (if (= subkey 3)
             (progn
               (princ "\nSelecione um ou mais MTEXT para carregar a lista: ")
               (setq ss (ssget '((0 . "MTEXT"))))
               (if ss
                 (progn
                   (setq all-lines nil i 0)
                   (while (< i (sslength ss))
                     (setq ename (ssname ss i) txt (ramais-get-full-mtext ename))
                     (setq all-lines (append all-lines (ramais-split-mtext txt)))
                     (setq i (1+ i))
                   )
                   (setq lst (ramais-parse-lines all-lines))
                   (ramais-write-file txtpath (ramais-format-file-data lst))
                   (princ (strcat "\ Foram carregados e unificados " (itoa (length lst)) " pontos a partir dos MTEXTs!"))
                 )
                 (princ "\nNenhum MTEXT foi selecionado.")
               )
             )
           )
          )
          ((= key 3)
           (setq ncol (ramais-dlg-colunas dclpath))
           (if ncol (ramais-gerar-mtext lst ncol))
          )
          (T (setq loop nil))
        )
      )
      (if (findfile dclpath) (vl-file-delete dclpath))
      (princ "\nComando RAMAIS encerrado.")
    )
  )
  (princ)
)

(princ "\nRAMAIS.LSP carregado. Digite RAMAIS para iniciar.")
(princ)