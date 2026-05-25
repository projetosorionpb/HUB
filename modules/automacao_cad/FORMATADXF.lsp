(vl-load-com)

(defun c:FORMATADXF ( / ssTextos ssVerdes ssCont ssStreet i ent obj ltype elist contAlteradas)
  (princ "\nIniciando formatação do DXF...")
  (vla-StartUndoMark (vla-get-ActiveDocument (vlax-get-acad-object)))

  ;; PASSOS 1 e 2: Textos nas layers ED_POLE e EO_WIRE_SEGMENT_INST -> Altura 1.5, Cor 7 (White/Black)
  (if (setq ssTextos (ssget "X" '((0 . "TEXT,MTEXT") (8 . "ED_POLE,EO_WIRE_SEGMENT_INST"))))
    (progn
      (setq i 0)
      (while (< i (sslength ssTextos))
        (setq obj (vlax-ename->vla-object (ssname ssTextos i)))
        (vl-catch-all-apply 'vla-put-Height (list obj 1.5))
        (vla-put-Color obj 7)
        (setq i (1+ i))
      )
      (princ (strcat "\n" (itoa i) " textos em ED_POLE/EO_WIRE... alterados (Altura 1.5 e Cor Branca)."))
    )
  )

  ;; PASSO 3: Linhas/Polilinhas VERDES na layer EO_WIRE_SEGMENT_INST -> Linetype TRACEJADA, Cor Azul
  (if (setq ssVerdes (ssget "X" '((0 . "LINE,*POLYLINE") (8 . "EO_WIRE_SEGMENT_INST") (62 . 3))))
    (progn
      (setq i 0)
      (while (< i (sslength ssVerdes))
        (setq obj (vlax-ename->vla-object (ssname ssVerdes i)))
        ;; Altera para TRACEJADA
        (vl-catch-all-apply 'vla-put-Linetype (list obj "TRACEJADA"))
        ;; Altera a cor para 5 (Azul)
        (vla-put-Color obj 5)
        (setq i (1+ i))
      )
      (princ (strcat "\n" (itoa i) " linhas verdes alteradas (Tracejada e Azul)."))
    )
  )

  ;; PASSO 4: Linhas/Polilinhas CONTINUOUS na layer EO_WIRE_SEGMENT_INST -> True Color 0,128,0
  (if (setq ssCont (ssget "X" '((0 . "LINE,*POLYLINE") (8 . "EO_WIRE_SEGMENT_INST"))))
    (progn
      (setq i 0)
      (setq contAlteradas 0)
      (while (< i (sslength ssCont))
        (setq ent (ssname ssCont i))
        (setq obj (vlax-ename->vla-object ent))
        (setq ltype (strcase (vla-get-Linetype obj)))
        
        ;; Verifica se o Linetype é Continuous (ou ByLayer)
        (if (or (= ltype "CONTINUOUS") (= ltype "BYLAYER"))
          (progn
            ;; RGB 0,128,0 = (0 * 65536) + (128 * 256) + 0 = 32768
            (setq elist (entget ent))
            ;; Remove cor índice (62) ou true color (420) existente
            (setq elist (vl-remove-if '(lambda (x) (or (= (car x) 62) (= (car x) 420))) elist))
            ;; Injeta o novo código True Color
            (setq elist (append elist '((420 . 32768))))
            (entmod elist)
            (setq contAlteradas (1+ contAlteradas))
          )
        )
        (setq i (1+ i))
      )
      (princ (strcat "\n" (itoa contAlteradas) " linhas contínuas alteradas (Verde Escuro RGB 0,128,0)."))
    )
  )

  ;; PASSO 5: Textos na layer LND_STREET_SEGMENT -> True Color 80,0,0
  (if (setq ssStreet (ssget "X" '((0 . "TEXT,MTEXT") (8 . "LND_STREET_SEGMENT"))))
    (progn
      (setq i 0)
      (while (< i (sslength ssStreet))
        (setq ent (ssname ssStreet i))
        (setq elist (entget ent))
        
        ;; RGB 80,0,0 = (80 * 65536) + (0 * 256) + 0 = 5242880
        ;; Remove qualquer cor existente da lista DXF da entidade
        (setq elist (vl-remove-if '(lambda (x) (or (= (car x) 62) (= (car x) 420))) elist))
        
        ;; Injeta o novo código True Color
        (setq elist (append elist '((420 . 5242880))))
        (entmod elist)
        
        (setq i (1+ i))
      )
      (princ (strcat "\n" (itoa i) " textos em LND_STREET_SEGMENT alterados (True Color 80,0,0)."))
    )
  )

  (vla-EndUndoMark (vla-get-ActiveDocument (vlax-get-acad-object)))
  (princ "\nEdição concluída com sucesso!")
  (princ)
)