(vl-load-com)

(defun c:PONTO (/ ss i en ed color txt p-pos j is-match num-str char n p1 p2 justify
                nextNumP nextNumF loop activeText activeColor x_str y_str)
  
  (setq nextNumP 1)
  (setq nextNumF 1)

  ;; Define a opção padrão na primeira vez que o comando roda
  (if (not *LastPointType*) (setq *LastPointType* "P"))

  ;; =========================================================
  ;; 1. Busca os NÚMEROS VERDES - Formato: (P#)
  ;; =========================================================
  (setq ss (ssget "X" '((0 . "TEXT,MTEXT") (1 . "*(P*)*") (410 . "Model"))))
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ed (entget (ssname ss i)))
        (setq color (assoc 62 ed))
        (if (and color (= (cdr color) 3)) 
          (progn
            (setq txt (strcase (cdr (assoc 1 ed))))
            (setq p-pos 0)
            (while (setq p-pos (vl-string-search "(P" txt p-pos))
              (setq j (+ p-pos 2) is-match T num-str "" char (substr txt (1+ j) 1))
              (while (and is-match (/= char ")") (/= char ""))
                (if (and (>= (ascii char) 48) (<= (ascii char) 57)) 
                  (setq num-str (strcat num-str char))
                  (setq is-match nil)
                )
                (setq j (1+ j) char (substr txt (1+ j) 1))
              )
              (if (and is-match (= char ")") (/= num-str ""))
                (setq nextNumP (max nextNumP (1+ (atoi num-str))))
              )
              (setq p-pos (1+ p-pos))
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )

  ;; =========================================================
  ;; 2. Busca os NÚMEROS AZUIS - Formato: F.P#
  ;; =========================================================
  (setq ss (ssget "X" '((0 . "TEXT,MTEXT") (1 . "*F.P*") (410 . "Model"))))
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ed (entget (ssname ss i)))
        (setq color (assoc 62 ed))
        (if (and color (= (cdr color) 5)) 
          (progn
            (setq txt (strcase (cdr (assoc 1 ed))))
            (setq p-pos 0)
            (while (setq p-pos (vl-string-search "F.P" txt p-pos))
              (setq j (+ p-pos 3) num-str "" char (substr txt (1+ j) 1))
              (while (and (/= char "") (>= (ascii char) 48) (<= (ascii char) 57))
                (setq num-str (strcat num-str char))
                (setq j (1+ j) char (substr txt (1+ j) 1))
              )
              (if (/= num-str "")
                (setq nextNumF (max nextNumF (1+ (atoi num-str))))
              )
              (setq p-pos (1+ p-pos))
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )

  ;; =========================================================
  ;; 3. Garante a existência da Layer FORMATO
  ;; =========================================================
  (if (not (tblsearch "LAYER" "FORMATO"))
    (command "-layer" "m" "FORMATO" "c" "7" "" "")
  )

  ;; =========================================================
  ;; 4. Loop de Criação (Compatível com NanoCAD 5)
  ;; =========================================================
  (setq loop T)
  (while loop
    ;; initget permite que o AutoCAD/NanoCAD aceite letras no lugar do clique
    (initget "P F C") 
    (setq p1 (getpoint (strcat "\n[P] Verde | [F] Azul | [C] Coords | Clique no centro <Atual: " *LastPointType* ">: ")))
    
    (cond
      ;; Se o usuário digitou P + Enter/Espaço
      ((= p1 "P") 
       (setq *LastPointType* "P")
       (princ "\n> Modo alterado para: VERDE (P#).")
      )
      
      ;; Se o usuário digitou F + Enter/Espaço
      ((= p1 "F") 
       (setq *LastPointType* "F")
       (princ "\n> Modo alterado para: AZUL (F.P#).")
      )

      ;; Se o usuário digitou C + Enter/Espaço
      ((= p1 "C") 
       (setq *LastPointType* "C")
       (princ "\n> Modo alterado para: COORDENADAS.")
      )
      
      ;; Se o usuário clicou em uma coordenada na tela (retorna uma lista X, Y, Z)
      ((listp p1)
       (setq p2 (getpoint p1 "\nClique no local do texto: "))
       (if p2
         (progn
           ;; Configura o texto e a cor baseando-se no modo ativo
           (cond
             ((= *LastPointType* "P")
              (setq activeText (strcat "(P" (itoa nextNumP) ")")
                    activeColor 3) ; 3 = Verde
             )
             ((= *LastPointType* "F")
              (setq activeText (strcat "F.P" (itoa nextNumF))
                    activeColor 5) ; 5 = Azul
             )
             ((= *LastPointType* "C")
              ;; Arredonda valores removendo casas decimais (rtos "numero" 2 0)
              (setq x_str (rtos (car p1) 2 0))
              (setq y_str (rtos (cadr p1) 2 0))
              ;; \P representa quebra de linha no MTEXT
              (setq activeText (strcat "X: 0" x_str "\\PY: " y_str))
              (setq activeColor 7) ; 7 = Branco/Preto
             )
           )

           ;; Define Justificativa baseada nos quadrantes X e Y
           (if (< (cadr p2) (cadr p1))
             ;; Clicou ABAIXO
             (if (< (car p2) (car p1)) (setq justify 3) (setq justify 1)) ; Top Right / Top Left
             ;; Clicou ACIMA
             (if (< (car p2) (car p1)) (setq justify 9) (setq justify 7)) ; Bottom Right / Bottom Left
           )

           ;; Criação do MTEXT usando entmake (método mais estável do CAD)
           (entmake (list
             '(0 . "MTEXT")
             '(100 . "AcDbEntity")
             '(8 . "FORMATO")  
             (cons 62 activeColor)         
             '(100 . "AcDbMText")
             (cons 10 p2)      
             (cons 1 activeText) 
             (cons 71 justify) 
             (cons 50 0.0)     
             (cons 40 1.6)     
           ))
           
           (if (= *LastPointType* "C")
              (princ "\nSucesso! Coordenadas criadas.")
              (princ (strcat "\nSucesso! Criado " activeText "."))
           )
           
           ;; Incrementa apenas o contador respectivo
           (if (= *LastPointType* "P") (setq nextNumP (1+ nextNumP)))
           (if (= *LastPointType* "F") (setq nextNumF (1+ nextNumF)))
         )
       )
      )
      
      ;; Se apertou Enter, Esc ou botão direito vazio (cancela o loop)
      (t (setq loop nil)) 
    )
  )
  
  (princ "\nComando finalizado.")
  (princ)
)