(defun c:SOMAP ( / ss addNum i count entName entData txtStr len newStr pos changed endPos foundParen midStr j isDigit charCode newNumStr)
  ;; Solicita ao usuário o valor a ser somado
  (setq addNum (getint "\nDigite o valor a ser somado aos textos: "))
  
  (if addNum
    (progn
      ;; Seleciona todos os textos (TEXT e MTEXT) no Model Space
      (setq ss (ssget "X" '((0 . "*TEXT") (410 . "Model"))))

      (if ss
        (progn
          (setq i 0 count 0)
          
          ;; Loop pelos textos selecionados
          (while (< i (sslength ss))
            (setq entName (ssname ss i))
            (setq entData (entget entName))
            (setq txtStr (cdr (assoc 1 entData)))
            (setq len (strlen txtStr))
            
            (setq newStr "")
            (setq pos 1)
            (setq changed nil)

            ;; Varredura caractere por caractere para encontrar o padrão "(P...)" no meio do texto
            (while (<= pos len)
              ;; Verifica se o caractere atual e o próximo formam "(P"
              (if (and (<= (+ pos 1) len)
                       (= (strcase (substr txtStr pos 2)) "(P")
                  )
                (progn
                  ;; Encontrou "(P", agora vamos caçar o fechamento ")"
                  (setq endPos (+ pos 2))
                  (setq foundParen nil)
                  
                  (while (and (<= endPos len) (not foundParen))
                    (if (= (substr txtStr endPos 1) ")")
                      (setq foundParen T)
                      (setq endPos (1+ endPos))
                    )
                  )

                  ;; Se encontrou o ")"
                  (if foundParen
                    (progn
                      ;; Extrai o que tem dentro do (P e do )
                      (setq midStr (substr txtStr (+ pos 2) (- endPos pos 2)))
                      
                      ;; Verifica se tem algo dentro e se é SÓ número
                      (if (> (strlen midStr) 0)
                        (progn
                          (setq j 1 isDigit T)
                          (while (and isDigit (<= j (strlen midStr)))
                            (setq charCode (ascii (substr midStr j 1)))
                            (if (or (< charCode 48) (> charCode 57))
                              (setq isDigit nil)
                            )
                            (setq j (1+ j))
                          )
                        )
                        (setq isDigit nil)
                      )

                      ;; Se for puramente número, realiza a soma e avança o cursor de leitura
                      (if isDigit
                        (progn
                          (setq newNumStr (itoa (+ (atoi midStr) addNum)))
                          (setq newStr (strcat newStr "(P" newNumStr ")"))
                          (setq pos (1+ endPos)) ;; Pula a leitura para depois do ")"
                          (setq changed T)
                        )
                        ;; Se não for número (ex: (P1A)), ignora e copia só o "(" para seguir lendo
                        (progn
                          (setq newStr (strcat newStr (substr txtStr pos 1)))
                          (setq pos (1+ pos))
                        )
                      )
                    )
                    ;; Se não achou o ")", copia só o "(" e segue lendo
                    (progn
                      (setq newStr (strcat newStr (substr txtStr pos 1)))
                      (setq pos (1+ pos))
                    )
                  )
                )
                ;; Se não for "(P", apenas copia a letra atual e avança
                (progn
                  (setq newStr (strcat newStr (substr txtStr pos 1)))
                  (setq pos (1+ pos))
                )
              )
            )

            ;; Se o texto sofreu alguma alteração, atualiza no CAD
            (if changed
              (progn
                (setq entData (subst (cons 1 newStr) (assoc 1 entData) entData))
                (entmod entData)
                (entupd entName)
                (setq count (1+ count))
              )
            )
            
            (setq i (1+ i))
          )
          (princ (strcat "\nConcluído: " (itoa count) " texto(s) modificado(s) automaticamente."))
        )
        (princ "\nNenhum texto encontrado no Model Space.")
      )
    )
    (princ "\nOperação cancelada.")
  )
  (princ)
)