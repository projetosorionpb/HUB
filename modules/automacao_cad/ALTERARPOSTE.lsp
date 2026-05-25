(defun c:alterarposte ( / sel ent vla_ent txt words pos dcl_filename f i dcl_id dcl_status doc space ins_pt txt_ht layer style rot str_m str_r str_i current_pt place_block result_list save_values clean-mtext )
  (vl-load-com)
  
  ;; --- FUNÇÃO DE LIMPEZA DE MTEXT ---
  ;; Remove qualquer cor, tachado ou fonte escondida dentro do MTEXT original
  (defun clean-mtext (str / idx char next_char res)
    (setq idx 1 res "")
    (while (<= idx (strlen str))
      (setq char (substr str idx 1))
      (cond
        ((or (= char "{") (= char "}"))
         (setq idx (1+ idx))
        )
        ((= char "\\")
         (if (<= (+ idx 1) (strlen str))
           (progn
             (setq next_char (strcase (substr str (1+ idx) 1)))
             (cond
               ((= next_char "\\") (setq res (strcat res "\\") idx (+ idx 2)))
               ((or (= next_char "P") (= next_char "N")) (setq res (strcat res " ") idx (+ idx 2)))
               ((vl-string-search next_char "LOK~") (setq idx (+ idx 2)))
               (t
                (setq idx (+ idx 2))
                (while (and (<= idx (strlen str)) (/= (substr str idx 1) ";"))
                  (setq idx (1+ idx))
                )
                (if (<= idx (strlen str)) (setq idx (1+ idx)))
               )
             )
           )
           (setq idx (1+ idx))
         )
        )
        (t (setq res (strcat res char) idx (1+ idx)))
      )
    )
    res
  )
  ;; -----------------------------------

  ;; 1. Seleção do Objeto
  (setq sel (entsel "\nSelecione o TEXT ou MTEXT referente ao poste: "))
  (if (not sel)
    (progn (princ "\nNenhum objeto selecionado.") (exit))
  )
  (setq ent (car sel))
  (setq vla_ent (vlax-ename->vla-object ent))

  ;; Verifica se é Texto ou MTexto
  (if (not (wcmatch (vla-get-objectname vla_ent) "AcDbText,AcDbMText"))
    (progn (princ "\nO objeto selecionado não é um TEXT ou MTEXT.") (exit))
  )

  ;; CAPTURA, LIMPA OS CÓDIGOS SUJOS E FORÇA PARA MAIÚSCULAS
  (setq txt (vla-get-textstring vla_ent))
  (setq txt (strcase (clean-mtext txt)))

  ;; Captura propriedades originais
  (setq ins_pt (vlax-get vla_ent 'InsertionPoint))
  (setq txt_ht (vla-get-height vla_ent))
  (setq layer (vla-get-layer vla_ent))
  (setq style (vla-get-StyleName vla_ent))
  (if (vlax-property-available-p vla_ent 'Rotation)
    (setq rot (vla-get-Rotation vla_ent))
    (setq rot 0.0)
  )

  ;; Define o ambiente de trabalho
  (setq doc (vla-get-activedocument (vlax-get-acad-object)))
  (setq space (vla-get-block (vla-get-activelayout doc)))

  ;; 2. Separar o texto por espaços (Remove múltiplos espaços gerados na limpeza)
  (while (vl-string-search "  " txt)
    (setq txt (vl-string-subst " " "  " txt))
  )
  
  (setq words nil)
  (setq pos (vl-string-search " " txt))
  (while pos
    (setq words (cons (substr txt 1 pos) words))
    (setq txt (substr txt (+ 2 pos)))
    (setq pos (vl-string-search " " txt))
  )
  (setq words (reverse (cons txt words)))
  (setq words (append words (list "")))

  ;; 3. Criar a interface DCL
  (setq dcl_filename (vl-filename-mktemp "altposte.dcl"))
  (setq f (open dcl_filename "w"))
  (write-line "altposte_dcl : dialog { label = \"Alterar Poste\";" f)
  (write-line "  : column {" f)
  (setq i 0)
  (foreach w words
    (write-line "    : row {" f)
    (write-line (strcat "      : edit_box { key = \"eb_" (itoa i) "\"; width = 30; }") f)
    (write-line (strcat "      : radio_row { key = \"rr_" (itoa i) "\";") f)
    (write-line (strcat "        : radio_button { label = \"Manter\"; key = \"m_" (itoa i) "\"; value = \"1\"; }") f)
    (write-line (strcat "        : radio_button { label = \"Instalar\"; key = \"i_" (itoa i) "\"; }") f)
    (write-line (strcat "        : radio_button { label = \"Remover\"; key = \"r_" (itoa i) "\"; }") f)
    (write-line "      }" f)
    (write-line "    }" f)
    (setq i (1+ i))
  )
  (write-line "  }" f)
  (write-line "  ok_cancel;" f)
  (write-line "}" f)
  (close f)

  ;; 4. Carregar form DCL
  (setq dcl_id (load_dialog dcl_filename))
  (if (not (new_dialog "altposte_dcl" dcl_id))
    (progn (princ "\nErro ao carregar DCL.") (exit))
  )

  ;; Preenche as caixas de texto
  (setq i 0)
  (foreach w words
    (set_tile (strcat "eb_" (itoa i)) w)
    (setq i (1+ i))
  )

  (defun save_values ()
    (setq result_list nil i 0)
    (repeat (length words)
      (setq w (strcase (get_tile (strcat "eb_" (itoa i)))))
      
      (setq mode "m")
      (if (= (get_tile (strcat "m_" (itoa i))) "1") (setq mode "m"))
      (if (= (get_tile (strcat "i_" (itoa i))) "1") (setq mode "i"))
      (if (= (get_tile (strcat "r_" (itoa i))) "1") (setq mode "r"))
      (setq result_list (append result_list (list (cons w mode))))
      (setq i (1+ i))
    )
  )

  (action_tile "accept" "(save_values) (done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)")

  (setq dcl_status (start_dialog))
  (unload_dialog dcl_id)
  (vl-file-delete dcl_filename)

  ;; 5. Processamento dos Textos
  (if (= dcl_status 1)
    (progn
      (setq str_m "" str_r "" str_i "")
      (foreach item result_list
        (setq w (car item) mode (cdr item))
        (if (and w (/= w ""))
          (cond
            ((= mode "m") (setq str_m (strcat str_m w " ")))
            ((= mode "r") (setq str_r (strcat str_r w " ")))
            ((= mode "i") (setq str_i (strcat str_i w " ")))
          )
        )
      )

      (if (> (strlen str_m) 0) (setq str_m (substr str_m 1 (1- (strlen str_m)))))
      (if (> (strlen str_r) 0) (setq str_r (substr str_r 1 (1- (strlen str_r)))))
      (if (> (strlen str_i) 0) (setq str_i (substr str_i 1 (1- (strlen str_i)))))

      (setq current_pt ins_pt)

      (defun place_block (txt color format_str is_box / mtxt minPt maxPt pt minL maxL step_dist pad pts rect final_txt)
        (if (and txt (> (strlen txt) 0))
          (progn
            (setq pt current_pt)
            
            (setq final_txt txt)
            (if format_str
              (setq final_txt (strcat format_str txt (if (= format_str "{\\K") "\\k}" "}")))
            )
            
            (setq mtxt (vla-addmtext space (vlax-3d-point pt) 0.0 final_txt))
            (vla-put-AttachmentPoint mtxt 7)
            (vla-put-InsertionPoint mtxt (vlax-3d-point pt))
            (vla-put-Height mtxt txt_ht)
            (vla-put-Layer mtxt layer)
            (vla-put-StyleName mtxt style)
            (vla-put-Color mtxt color) 
            
            (vla-update mtxt)
            (vla-GetBoundingBox mtxt 'minPt 'maxPt)
            (setq minL (vlax-safearray->list minPt))
            (setq maxL (vlax-safearray->list maxPt))
            
            (setq step_dist (- (car maxL) (car minL)))
            
            (if (and rot (/= rot 0.0))
              (vla-put-Rotation mtxt rot)
            )
            
            (if is_box
              (progn
                (setq pad (* 0.2 txt_ht))
                (setq pts (vlax-make-safearray vlax-vbDouble '(0 . 7)))
                (vlax-safearray-fill pts (list 
                   (- (car minL) pad) (- (cadr minL) pad)
                   (+ (car maxL) pad) (- (cadr minL) pad)
                   (+ (car maxL) pad) (+ (cadr maxL) pad)
                   (- (car minL) pad) (+ (cadr maxL) pad)
                ))
                (setq rect (vla-AddLightWeightPolyline space pts))
                (vla-put-Closed rect :vlax-true)
                (vla-put-Color rect color)
                (vla-put-Layer rect layer)
                (vla-put-Elevation rect (caddr pt))
                
                (if (and rot (/= rot 0.0))
                   (vla-Rotate rect (vlax-3d-point pt) rot)
                )
              )
            )
            
            (setq current_pt (polar pt rot (+ step_dist (* 0.4 txt_ht))))
          )
        )
      )

      (place_block str_m 7 nil nil)
      (place_block str_r 8 "{\\K" nil)
      (place_block str_i 1 nil T)

      (vla-delete vla_ent)
      (princ "\nPoste atualizado: Formatações antigas ignoradas e textos limpos com sucesso!")
    )
    (princ "\nOperação cancelada pelo usuário.")
  )
  (princ)
)