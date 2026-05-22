(vl-load-com)

;;; FUNÇÃO PARA ENCONTRAR O PRÓXIMO NÚMERO C# (Apenas no Layout Atual)
(defun get-next-c-num ( / ss i txt maxNum pos j char numStr ctab)
  (setq maxNum 0)
  (setq ctab (getvar "CTAB"))
  (if (setq ss (ssget "X" (list '(0 . "MTEXT,TEXT") (cons 410 ctab))))
    (repeat (setq i (sslength ss))
      (setq txt (cdr (assoc 1 (entget (ssname ss (setq i (1- i)))))))
      (setq pos 0)
      (while (setq pos (vl-string-search "C" (strcase txt) pos))
        (setq numStr "")
        (setq j (1+ pos))
        (while (and (< j (strlen txt))
                    (>= (ascii (setq char (substr txt (1+ j) 1))) 48)
                    (<= (ascii char) 57))
          (setq numStr (strcat numStr char))
          (setq j (1+ j))
        )
        (if (> (strlen numStr) 0)
          (if (> (atoi numStr) maxNum)
            (setq maxNum (atoi numStr))
          )
        )
        (setq pos (1+ pos))
      )
    )
  )
  (1+ maxNum)
)

;;; FUNÇÃO PARA DESENHAR O RETÂNGULO DA PODA E ROÇO
(defun draw-mtext-box (obj activeSpace / minpt maxpt p1 p2 p3 p4 coords arr poly offset)
  (vla-GetBoundingBox obj 'minpt 'maxpt)
  (setq p1 (vlax-safearray->list minpt)
        p3 (vlax-safearray->list maxpt))
  (setq offset (* (vla-get-Height obj) 0.3))
  (setq p1 (list (- (car p1) offset) (- (cadr p1) offset) 0.0)
        p3 (list (+ (car p3) offset) (+ (cadr p3) offset) 0.0))
  (setq p2 (list (car p3) (cadr p1) 0.0)
        p4 (list (car p1) (cadr p3) 0.0))
  (setq coords (list (car p1) (cadr p1) (car p2) (cadr p2) (car p3) (cadr p3) (car p4) (cadr p4)))
  (setq arr (vlax-make-safearray vlax-vbDouble '(0 . 7)))
  (vlax-safearray-fill arr coords)
  (setq poly (vla-AddLightWeightPolyline activeSpace arr))
  (vla-put-Closed poly :vlax-true)
  (vla-put-Color poly 1)
  (vla-put-Layer poly "0")
  poly
)

;;; COMANDO PRINCIPAL
(defun c:CERCA ( / *error* dcl_file f dcl_id status opt_op opt_fios opt_mode opt_podas opt_tamanho
                 opt_roco_metros opt_roco_mode opt_lado_anot
                 acadObj doc activeSpace ent sel obj len mid-pt mid-param mid-deriv mid-ang
                 c-num mtext-str start-pt start-deriv start-ang end-pt end-deriv end-ang
                 ptlst pt arr coords blk-terra blk-sec-start blk-sec-end text-pt text-ang blk-ang
                 offset-dist offset-ang nome-bloco-sec mtext-obj i count txt_str tmp-lines tmp-line
                 p1_medir p2_medir roco-val attach-pt dx dy poly-box int-pts p-list idx pt-first pt-last old-os
                 pt-side ang-click wants-case-a is-currently-case-a pt-offset ang-offset ang-diff)

  ;; Tratamento de erros e interrupção (ESC)
  (defun *error* (msg)
    (if (and doc activeSpace) (vla-EndUndoMark doc))
    (if old-os (setvar "OSMODE" old-os))
    (if (not (wcmatch (strcase msg t) "*BREAK*,*CANCEL*,*EXIT*"))
      (princ (strcat "\nErro: " msg))
    )
    (princ)
  )

  (setq acadObj     (vlax-get-acad-object)
        doc         (vla-get-ActiveDocument acadObj)
        activeSpace (vla-get-Block (vla-get-ActiveLayout doc)))
        
  (vla-StartUndoMark doc) ;; Inicia a marcação de desfazer (Ctrl+Z)

  ;; ── FUNÇÃO INTERNA: lê tiles e fecha o diálogo ──────────────────────────
  (defun -cerca-accept- ()
    (if (= (get_tile "op_cerca") "1") (setq opt_op "op_cerca"))
    (if (= (get_tile "op_poda")  "1") (setq opt_op "op_poda"))
    (if (= (get_tile "op_roco")  "1") (setq opt_op "op_roco"))
    (if (= (get_tile "mode_draw")  "1") (setq opt_mode "mode_draw"))
    (if (= (get_tile "mode_trans") "1") (setq opt_mode "mode_trans"))
    (if (= (get_tile "lado_auto")    "1") (setq opt_lado_anot "lado_auto"))
    (if (= (get_tile "lado_definir") "1") (setq opt_lado_anot "lado_definir"))
    (if (= (get_tile "size_p") "1") (setq opt_tamanho "P"))
    (if (= (get_tile "size_m") "1") (setq opt_tamanho "M"))
    (if (= (get_tile "size_g") "1") (setq opt_tamanho "G"))
    (if (= (get_tile "roco_inserir") "1") (setq opt_roco_mode "mode_inserir"))
    (if (= (get_tile "roco_medir")   "1") (setq opt_roco_mode "mode_medir"))
    (setq opt_fios        (get_tile "num_fios"))
    (setq opt_podas       (get_tile "num_podas"))
    (setq opt_roco_metros (get_tile "metros_roco"))
    (done_dialog 1)
  )

  ;; 1. GERAÇÃO DO DCL
  (setq dcl_file (vl-filename-mktemp "faux_dialog.dcl"))
  (setq f (open dcl_file "w"))
  (write-line "faux_dialog : dialog {" f)
  (write-line "  label = \"Ferramenta Auxiliar\";" f)
  (write-line "  : boxed_radio_column { label = \"Operação\";" f)
  (write-line "    : radio_button { label = \"Cerca\"; key = \"op_cerca\"; }" f)
  (write-line "    : radio_button { label = \"Poda\";  key = \"op_poda\";  }" f)
  (write-line "    : radio_button { label = \"Roço\";  key = \"op_roco\";  }" f)
  (write-line "  }" f)
  (write-line "  : boxed_column { label = \"Opções de Cerca\"; key = \"box_cerca\";" f)
  (write-line "    : edit_box { label = \"Número de fios:\"; key = \"num_fios\"; edit_width = 10; }" f)
  (write-line "    : radio_row { label = \"Lado da anotação:\";" f)
  (write-line "      : radio_button { label = \"Automático\"; key = \"lado_auto\";    }" f)
  (write-line "      : radio_button { label = \"Definir\";    key = \"lado_definir\"; }" f)
  (write-line "    }" f)
  (write-line "    : radio_row {" f)
  (write-line "      : radio_button { label = \"Desenhar\";    key = \"mode_draw\";  }" f)
  (write-line "      : radio_button { label = \"Transformar\"; key = \"mode_trans\"; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "  : boxed_column { label = \"Opções de Poda\"; key = \"box_poda\";" f)
  (write-line "    : edit_box { label = \"Número de podas:\"; key = \"num_podas\"; edit_width = 10; }" f)
  (write-line "    : radio_row { label = \"Tamanho:\";" f)
  (write-line "      : radio_button { label = \"P\"; key = \"size_p\"; }" f)
  (write-line "      : radio_button { label = \"M\"; key = \"size_m\"; }" f)
  (write-line "      : radio_button { label = \"G\"; key = \"size_g\"; }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "  : boxed_column { label = \"Opções de Roço\"; key = \"box_roco\";" f)
  (write-line "    : edit_box { label = \"Metros de roço:\"; key = \"metros_roco\"; edit_width = 10; }" f)
  (write-line "    : radio_row {" f)
  (write-line "      : radio_button { label = \"Inserir\"; key = \"roco_inserir\"; }" f)
  (write-line "      : radio_button { label = \"Medir\";   key = \"roco_medir\";   }" f)
  (write-line "    }" f)
  (write-line "  }" f)
  (write-line "  ok_cancel;" f)
  (write-line "}" f)
  (close f)

  ;; 2. CARREGA E INICIALIZA O DIÁLOGO
  (setq dcl_id (load_dialog dcl_file))
  (if (not (new_dialog "faux_dialog" dcl_id)) (exit))

  (set_tile "op_cerca"     "1")
  (set_tile "mode_draw"    "1")
  (set_tile "lado_auto"    "1")
  (set_tile "size_m"       "1")
  (set_tile "roco_inserir" "1")
  (set_tile "num_fios"     "5")
  (set_tile "num_podas"    "1")
  (set_tile "metros_roco"  "10")

  (mode_tile "box_poda" 1)
  (mode_tile "box_roco" 1)

  (action_tile "op_cerca" "(mode_tile \"box_cerca\" 0)(mode_tile \"box_poda\" 1)(mode_tile \"box_roco\" 1)")
  (action_tile "op_poda"  "(mode_tile \"box_cerca\" 1)(mode_tile \"box_poda\" 0)(mode_tile \"box_roco\" 1)")
  (action_tile "op_roco"  "(mode_tile \"box_cerca\" 1)(mode_tile \"box_poda\" 1)(mode_tile \"box_roco\" 0)")
  (action_tile "accept"   "(-cerca-accept-)")
  (action_tile "cancel"   "(done_dialog 0)")

  (setq status (start_dialog))
  (unload_dialog dcl_id)
  (vl-file-delete dcl_file)

  (if (= status 1)
    (progn

      ;; ============================================================
      ;; LÓGICA DE CERCA
      ;; ============================================================
      (if (= opt_op "op_cerca")
        (progn
          (if (not (tblsearch "LAYER" "06- CERCADO")) (command "_.-layer" "_M" "06- CERCADO" "_C" 2 "" ""))
          (if (not (tblsearch "LAYER" "0"))           (command "_.-layer" "_M" "0" "" ""))

          (setq ent nil)
          (if (= opt_mode "mode_draw")
            (progn
              (setq ptlst nil tmp-lines nil)
              (setq pt (getpoint "\nEspecifique o ponto inicial: "))
              (if pt
                (progn
                  (setq ptlst (cons pt ptlst))
                  (while (setq pt (getpoint (car ptlst) "\nPróximo ponto (Enter para concluir): "))
                    (grdraw (car ptlst) pt 3)
                    (setq tmp-line (entmakex (list '(0 . "LINE") (cons 10 (car ptlst)) (cons 11 pt) '(62 . 3))))
                    (if tmp-line (progn (entupd tmp-line) (setq tmp-lines (cons tmp-line tmp-lines))))
                    (setq ptlst (cons pt ptlst))
                  )
                  (foreach l tmp-lines (if l (entdel l)))
                  (command "_.redraw")
                  (setq ptlst (reverse ptlst))
                  (if (> (length ptlst) 1)
                    (progn
                      (setq coords (apply 'append (mapcar '(lambda (p) (list (car p) (cadr p))) ptlst)))
                      (setq arr (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
                      (vlax-safearray-fill arr coords)
                      (setq ent (vlax-vla-object->ename (vla-AddLightWeightPolyline activeSpace arr)))
                    )
                  )
                )
              )
            )
            (progn
              (setq sel (entsel "\nSelecione a linha ou polilinha para transformar: "))
              (if sel (setq ent (car sel)))
            )
          )

          (if ent
            (progn
              (setq obj (vlax-ename->vla-object ent))
              (vla-put-Layer obj "06- CERCADO")
              (if (tblsearch "LTYPE" "CERCA") (vla-put-Linetype obj "CERCA"))
              (vla-put-LinetypeScale obj 5.0)
              (vla-Update obj)

              (setq len (vlax-curve-getDistAtParam obj (vlax-curve-getEndParam obj)))
              (if (> len 0)
                (progn
                  (setq mid-pt  (vlax-curve-getPointAtDist obj (/ len 2.0)))
                  (setq mid-ang (angle '(0 0) (list (car  (setq mid-deriv (vlax-curve-getFirstDeriv obj (vlax-curve-getParamAtPoint obj mid-pt)))) (cadr mid-deriv))))

                  ;; ROTAÇÃO E POSICIONAMENTO (calcula offset padrão primeiro)
                  (if (and (> mid-ang (/ pi 2.0)) (<= mid-ang (* 1.5 pi)))
                    (progn
                      (setq text-ang    (- mid-ang pi))
                      (setq offset-ang  (- text-ang (/ pi 2.0)))
                      (setq offset-dist 10.5)
                    )
                    (progn
                      (setq text-ang    mid-ang)
                      (setq offset-ang  (+ text-ang (/ pi 2.0)))
                      (setq offset-dist 10.5)
                    )
                  )

                  ;; LADO DA ANOTAÇÃO
                  (if (= opt_lado_anot "lado_definir")
                    (progn
                      (setq pt-side (getpoint mid-pt "\nClique no lado onde deve ficar a anotação: "))
                      (if pt-side
                        (progn
                          (setq ang-click  (angle mid-pt pt-side))
                          (setq pt-offset  (polar mid-pt offset-ang 1.0))
                          (setq ang-offset (angle mid-pt pt-offset))
                          (setq ang-diff (abs (- ang-click ang-offset)))
                          (if (> ang-diff pi) (setq ang-diff (- (* 2 pi) ang-diff)))
                          (if (> ang-diff (/ pi 2.0))
                            (setq offset-ang (+ offset-ang pi))
                          )
                        )
                      )
                    )
                  )

                  ;; --------------------------------------------------------
                  ;; INSERÇÃO DO BLOCO TERRA CERCA (+ 270° graus)
                  ;; --------------------------------------------------------
                  ;; Recalcula blk-ang SOMANDO 270 graus (* 1.5 pi)
                  (setq blk-ang (+ offset-ang (* 1.5 pi)))

                  (if (tblsearch "BLOCK" "Terra cerca")
                    (vla-put-Layer (vla-InsertBlock activeSpace (vlax-3d-point mid-pt) "Terra cerca" 1 1 1 blk-ang) "0")
                  )

                  ;; --------------------------------------------------------
                  ;; CRIAÇÃO DO TEXTO E BLOCOS DAS EXTREMIDADES
                  ;; --------------------------------------------------------
                  (setq c-num    (get-next-c-num))
                  (setq mtext-obj (vla-AddMText activeSpace (vlax-3d-point (polar mid-pt offset-ang offset-dist)) 0.0 (strcat "C" (itoa c-num) "\\P" opt_fios " FIOS")))
                  (vla-put-AttachmentPoint mtext-obj 5)
                  (vla-put-InsertionPoint  mtext-obj (vlax-3d-point (polar mid-pt offset-ang offset-dist)))
                  (vla-put-Height   mtext-obj 2.0)
                  (vla-put-Rotation mtext-obj text-ang)
                  (vla-put-Layer    mtext-obj "06- CERCADO")

                  (setq nome-bloco-sec (if (tblsearch "BLOCK" "seccionamento cerca") "seccionamento cerca" "seccionador cerca"))
                  (if (tblsearch "BLOCK" nome-bloco-sec)
                    (progn
                      (vla-put-Layer (vla-InsertBlock activeSpace (vlax-3d-point (vlax-curve-getStartPoint obj)) nome-bloco-sec 1 1 1 (angle '(0 0) (list (car (setq start-deriv (vlax-curve-getFirstDeriv obj (vlax-curve-getStartParam obj)))) (cadr start-deriv)))) "0")
                      (vla-put-Layer (vla-InsertBlock activeSpace (vlax-3d-point (vlax-curve-getEndPoint   obj)) nome-bloco-sec 1 1 1 (angle '(0 0) (list (car (setq end-deriv   (vlax-curve-getFirstDeriv obj (vlax-curve-getEndParam   obj)))) (cadr end-deriv))))   "0")
                    )
                  )
                  (command "_.regen")
                  (princ (strcat "\nCerca C" (itoa c-num) " processada com sucesso!"))
                )
              )
            )
          )
        )
      )

      ;; ============================================================
      ;; LÓGICA DE PODA
      ;; ============================================================
      (if (= opt_op "op_poda")
        (progn
          (setq i (atoi opt_podas) count 1)
          (while (<= count i)
            (setq pt (getpoint (strcat "\nClique para posicionar o bloco PODA (" (itoa count) "/" opt_podas "): ")))
            (if pt
              (progn
                (if (tblsearch "BLOCK" "PODA")
                  (vla-put-Layer (vla-InsertBlock activeSpace (vlax-3d-point pt) "PODA" 1 1 1 0) "0")
                  (princ "\n[Aviso]: Bloco 'PODA' não encontrado!")
                )
                (setq count (1+ count))
              )
              (setq count (1+ i))
            )
          )
          (if (<= count (1+ i))
            (progn
              (setq text-pt (getpoint "\nClique para posicionar a anotação da Poda: "))
              (if text-pt
                (progn
                  (setq txt_str (strcat opt_podas " PODA" (if (> i 1) "S " " ") opt_tamanho))
                  (setq mtext-obj (vla-AddMText activeSpace (vlax-3d-point text-pt) 0.0 txt_str))
                  (vla-put-AttachmentPoint mtext-obj 7)
                  (vla-put-InsertionPoint  mtext-obj (vlax-3d-point text-pt))
                  (vla-put-Color  mtext-obj 1)
                  (vla-put-Layer  mtext-obj "0")
                  (vla-put-Height mtext-obj 2.0)
                  (vla-Update mtext-obj)
                  (draw-mtext-box mtext-obj activeSpace)
                  (command "_.regen")
                  (princ "\nPoda finalizada com sucesso!")
                )
              )
            )
          )
        )
      )

      ;; ============================================================
      ;; LÓGICA DE ROÇO
      ;; ============================================================
      (if (= opt_op "op_roco")
        (progn
          (if (not (tblsearch "LAYER" "0")) (command "_.-layer" "_M" "0" "" ""))
          (setq roco-val opt_roco_metros)

          (if (= opt_roco_mode "mode_medir")
            (progn
              (setq p1_medir (getpoint "\nEspecifique o primeiro ponto para MEDIR o roço: "))
              (if p1_medir
                (setq p2_medir (getpoint p1_medir "\nEspecifique o segundo ponto para MEDIR: "))
              )
              (if (and p1_medir p2_medir)
                (setq roco-val (rtos (distance p1_medir p2_medir) 2 0))
                (setq roco-val "0")
              )
            )
          )

          (setq ptlst nil tmp-lines nil)
          (setq pt (getpoint "\nEspecifique o ponto inicial da LINHA do Roço: "))
          (if pt
            (progn
              (setq ptlst (cons pt ptlst))
              (while (setq pt (getpoint (car ptlst) "\nPróximo ponto (Enter para concluir): "))
                (grdraw (car ptlst) pt 1)
                (setq tmp-line (entmakex (list '(0 . "LINE") (cons 10 (car ptlst)) (cons 11 pt) '(62 . 1))))
                (if tmp-line (progn (entupd tmp-line) (setq tmp-lines (cons tmp-line tmp-lines))))
                (setq ptlst (cons pt ptlst))
              )
              (foreach l tmp-lines (if l (entdel l)))
              (command "_.redraw")

              (setq ptlst (reverse ptlst))
              (if (> (length ptlst) 1)
                (progn
                  (setq coords (apply 'append (mapcar '(lambda (p) (list (car p) (cadr p))) ptlst)))
                  (setq arr (vlax-make-safearray vlax-vbDouble (cons 0 (1- (length coords)))))
                  (vlax-safearray-fill arr coords)
                  (setq obj (vla-AddLightWeightPolyline activeSpace arr))
                  (vla-put-Layer  obj "0")
                  (vla-put-Color  obj 1)
                  (vla-Update obj)

                  (setq mid-pt  (vlax-curve-getPointAtDist obj (/ (vlax-curve-getDistAtParam obj (vlax-curve-getEndParam obj)) 2.0)))
                  (setq mid-ang (angle '(0 0) (list (car (setq mid-deriv (vlax-curve-getFirstDeriv obj (vlax-curve-getParamAtPoint obj mid-pt)))) (cadr mid-deriv))))

                  (setq offset-ang  (- mid-ang (/ pi 2.0))
                        offset-dist 3.0)
                  (setq text-pt (polar mid-pt offset-ang offset-dist))

                  (setq dx (- (car text-pt) (car mid-pt))
                        dy (- (cadr text-pt) (cadr mid-pt)))
                  (setq attach-pt (if (> (abs dx) (abs dy)) (if (> dx 0) 7 9) (if (>= dy 0) 7 9)))

                  (setq txt_str (strcat "ABRIR RO" (chr 199) "O " roco-val " METROS"))
                  (setq mtext-obj (vla-AddMText activeSpace (vlax-3d-point text-pt) 0.0 txt_str))
                  (vla-put-AttachmentPoint mtext-obj attach-pt)
                  (vla-put-InsertionPoint  mtext-obj (vlax-3d-point text-pt))
                  (vla-put-Height   mtext-obj 2.0)
                  (vla-put-Rotation mtext-obj 0.0)
                  (vla-put-Layer    mtext-obj "0")
                  (vla-put-Color    mtext-obj 1)
                  (vla-Update mtext-obj)

                  (setq poly-box (draw-mtext-box mtext-obj activeSpace))

                  (setq int-pts (vl-catch-all-apply 'vlax-invoke (list obj 'IntersectWith poly-box 0)))
                  (if (and (not (vl-catch-all-error-p int-pts)) int-pts (> (length int-pts) 2))
                    (progn
                      (setq p-list nil idx 0)
                      (while (< idx (length int-pts))
                        (setq p-list (cons (list (nth idx int-pts) (nth (+ idx 1) int-pts) (nth (+ idx 2) int-pts)) p-list))
                        (setq idx (+ idx 3))
                      )
                      (setq p-list (vl-sort p-list '(lambda (a b) (< (vlax-curve-getParamAtPoint obj a) (vlax-curve-getParamAtPoint obj b)))))
                      (setq pt-first (car p-list)  pt-last (last p-list))
                      (setq old-os (getvar "OSMODE"))
                      (setvar "OSMODE" 0)
                      (command "_.BREAK" (list (vlax-vla-object->ename obj) pt-first) "_F" "_non" pt-first "_non" pt-last)
                      (setvar "OSMODE" old-os)
                    )
                  )
                  (command "_.regen")
                  (princ (strcat "\nRo" (chr 199) "o de " roco-val " metros inserido com sucesso!"))
                )
              )
            )
          )
        )
      )
    )
  )
  
  (vla-EndUndoMark doc) ;; Finaliza a marcação de desfazer
  (princ)
)