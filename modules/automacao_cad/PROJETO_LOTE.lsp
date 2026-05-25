;; PROJETO_LOTE.lsp — Insercao em lote de POSTES e CABOS via projeto.csv
;; Substitui o uso simultâneo de POSTE_LOTE.lsp + CABO_LOTE.lsp.
;; Arquivo autonomo: nao requer DCL externo. Entrada via linha de comando.
;;
;; Formato esperado (projeto.csv gerado pelo conversor_postes.html):
;;   [POSTES]
;;   X;Y;TIPO;DESC_I;TERRA;TRAFO;POT_KVA;CHAVE;QTD;ELO;PR;BASE;DESC_R;TRAFO_R;POT_R;CHAVE_R;QTD_R;ELO_R;ANGULO_GRAUS;PONTO
;;   ...dados...
;;
;;   [CABOS]
;;   REDE;TIPO;ORIGEM_X;ORIGEM_Y;DESTINO_X;DESTINO_Y;CONDUTOR_I;FASES_I;CONDUTOR_R;FASES_R;DIST
;;   ...dados...
;;
;; Angulo dos postes (prioridade):
;;   1) ANGULO_GRAUS preenchido no CSV (vem do DXF)
;;   2) Calculado pela rede — direcao media dos cabos conectados ao poste
;;   3) Fallback: sequencia de coordenadas dos postes vizinhos
;;
;; Historico:
;;   [v1] Criado — unifica POSTE_LOTE.lsp e CABO_LOTE.lsp num unico comando.
;;   [v2] Removida dependencia do DCL externo. Entrada via getfiled/getreal.


;;; ============================================================
;;; UTILITARIOS COMPARTILHADOS
;;; ============================================================

(defun prj-trim (s)
  (setq s (vl-string-subst "" "\r" s))
  (setq s (vl-string-subst "" "\n" s))
  (vl-string-trim " \t" s))

(defun prj-split-csv (str / result cur i c sep)
  (setq sep (if (vl-string-search ";" str) ";" ","))
  (setq result '()  cur ""  i 0)
  (while (< i (strlen str))
    (setq i (1+ i)  c (substr str i 1))
    (if (= c sep)
      (setq result (append result (list cur))  cur "")
      (setq cur (strcat cur c))))
  (append result (list cur)))

(defun prj-atof-br (s)
  (atof (vl-string-subst "." "," (prj-trim s))))

(defun prj-field (lst n)
  (if (and lst (>= (length lst) (1+ n)))
    (prj-trim (nth n lst))
    ""))


;;; ============================================================
;;; SECAO POSTES — parse e calculo de angulo
;;; ============================================================

(defun prj-parse-poste (campos / f v)
  (defun f (n) (prj-field campos n))
  (list
    (cons 'X        (prj-atof-br (f 0)))
    (cons 'Y        (prj-atof-br (f 1)))
    (cons 'TIPO     (strcase (f 2)))
    (cons 'DESC_I   (strcase (f 3)))
    (cons 'TERRA    (if (= (f 4) "1") 1 0))
    (cons 'TRAFO    (if (= (f 5) "1") 1 0))
    (cons 'POT_KVA  (if (= (prj-trim (f 6)) "") "112,5" (prj-trim (f 6))))
    (cons 'CHAVE    (if (= (f 7) "1") 1 0))
    (cons 'QTD      (if (= (prj-trim (f 8)) "3") "3" "1"))
    (cons 'ELO      (if (= (prj-trim (f 9)) "")  "1H"  (prj-trim (f 9))))
    (cons 'PR       (progn
                      (setq v (strcase (prj-trim (f 10))))
                      (cond ((= v "PRMT")  "PRMT")
                            ((= v "PRBT")  "PRBT")
                            ((= v "AMBOS") "Ambos")
                            (T             "Nenhum"))))
    (cons 'BASE     (if (= (f 11) "1") 1 0))
    (cons 'DESC_R   (strcase (f 12)))
    (cons 'TRAFO_R  (if (= (f 13) "1") 1 0))
    (cons 'POT_R    (if (= (prj-trim (f 14)) "") "112,5" (prj-trim (f 14))))
    (cons 'CHAVE_R  (if (= (f 15) "1") 1 0))
    (cons 'QTD_R    (if (= (prj-trim (f 16)) "3") "3" "1"))
    (cons 'ELO_R    (if (= (prj-trim (f 17)) "") "1H"  (prj-trim (f 17))))
    (cons 'ANGULO_DXF (prj-trim (f 18)))))

(defun prj-angulo-entre (p1 p2)
  (atan (- (cadr p2) (cadr p1))
        (- (car  p2) (car  p1))))

(defun prj-media-angular (a1 a2 / diff)
  (setq diff (- a2 a1))
  (while (>  diff pi)     (setq diff (- diff (* 2.0 pi))))
  (while (<= diff (- pi)) (setq diff (+ diff (* 2.0 pi))))
  (+ a1 (/ diff 2.0)))

;; Calcula angulo por sequencia de coordenadas (fallback)
(defun prj-calcular-angulos (lista_dados ang_fallback
                              / n i pa pb pc a_ante a_prox result)
  (setq n (length lista_dados)  result '())
  (cond
    ((= n 0) result)
    ((= n 1) (list ang_fallback))
    (T
     (setq i 0)
     (while (< i n)
       (setq pb (nth i lista_dados))
       (setq result
         (append result
           (list
             (cond
               ((= i 0)
                (setq pc (nth 1 lista_dados))
                (prj-angulo-entre
                  (list (cdr (assoc 'X pb)) (cdr (assoc 'Y pb)))
                  (list (cdr (assoc 'X pc)) (cdr (assoc 'Y pc)))))
               ((= i (1- n))
                (setq pa (nth (1- i) lista_dados))
                (prj-angulo-entre
                  (list (cdr (assoc 'X pa)) (cdr (assoc 'Y pa)))
                  (list (cdr (assoc 'X pb)) (cdr (assoc 'Y pb)))))
               (T
                (setq pa (nth (1- i) lista_dados)
                      pc (nth (1+ i) lista_dados))
                (setq a_ante (prj-angulo-entre
                               (list (cdr (assoc 'X pa)) (cdr (assoc 'Y pa)))
                               (list (cdr (assoc 'X pb)) (cdr (assoc 'Y pb))))
                      a_prox (prj-angulo-entre
                               (list (cdr (assoc 'X pb)) (cdr (assoc 'Y pb)))
                               (list (cdr (assoc 'X pc)) (cdr (assoc 'Y pc)))))
                (prj-media-angular a_ante a_prox))))))
       (setq i (1+ i)))
     result))
  result)

;; Calcula angulo pela rede usando segmentos ja lidos (lista de (ox oy dx dy))
(defun prj-angulos-pela-rede (lista_dados segmentos fallback_list tol
                               / result px py angs a i)
  (setq result '()  i 0)
  (foreach dados lista_dados
    (setq px (cdr (assoc 'X dados))
          py (cdr (assoc 'Y dados))
          angs '())
    (foreach seg segmentos
      (setq ox (nth 0 seg) oy (nth 1 seg)
            dx (nth 2 seg) dy (nth 3 seg))
      (cond
        ((and (<= (abs (- px ox)) tol) (<= (abs (- py oy)) tol))
         (setq angs (append angs
                      (list (prj-angulo-entre (list ox oy) (list dx dy))))))
        ((and (<= (abs (- px dx)) tol) (<= (abs (- py dy)) tol))
         (setq angs (append angs
                      (list (prj-angulo-entre (list dx dy) (list ox oy))))))))
    (cond
      ((null angs)         (setq result (append result (list (nth i fallback_list)))))
      ((= (length angs) 1) (setq result (append result (list (car angs)))))
      (T
       (setq a (car angs))
       (foreach ang_extra (cdr angs)
         (setq a (prj-media-angular a ang_extra)))
       (setq result (append result (list a)))))
    (setq i (1+ i)))
  result)


;;; ============================================================
;;; SECAO POSTES — insercao no DXF
;;; ============================================================

(defun prj-inserir-poste (dados off_x off_y ang_rad
                           / tipo desc_I desc_R
                             has_trafo_I has_chave_I has_trafo_R has_chave_R has_prbt_I
                             only_bt nodes_I draw_nodes_I
                             extra_blocks_I extra_blocks_R
                             trafo_txt_I chave_txt_I trafo_txt_R chave_txt_R
                             base_ang offset_dist
                             p1 final_p1_I final_p1_R ref_pt
                             blocks_data texts_list_I texts_list_R
                             base_X base_Y cur_Y justify lado
                             t_str style ent_txt vla_obj minpt maxpt min_l max_l
                             txtH pad_v pad_h pad_risco box_gap)

  (setq txtH      1.5
        pad_v     0.40
        pad_h     0.50
        pad_risco 0.20
        box_gap   0.30)

  (setq tipo   (cdr (assoc 'TIPO   dados))
        desc_I (cdr (assoc 'DESC_I dados))
        desc_R (cdr (assoc 'DESC_R dados)))

  (if (= tipo "R")
    (progn (setq desc_R desc_I  desc_I "")))

  (setq has_trafo_I (= (cdr (assoc 'TRAFO   dados)) 1)
        has_chave_I (= (cdr (assoc 'CHAVE   dados)) 1)
        has_trafo_R (= (cdr (assoc 'TRAFO_R dados)) 1)
        has_chave_R (= (cdr (assoc 'CHAVE_R dados)) 1)
        has_prbt_I  (or (= (cdr (assoc 'PR dados)) "PRBT")
                        (= (cdr (assoc 'PR dados)) "Ambos")))

  (if has_trafo_I
    (setq trafo_txt_I
      (if (= (cdr (assoc 'POT_KVA dados)) "25")
        "TR - 1 - 25kVA"
        (strcat "TR - 3 - " (cdr (assoc 'POT_KVA dados)) "kVA"))))
  (if has_chave_I
    (setq chave_txt_I
      (strcat (cdr (assoc 'QTD dados)) " - 100A - " (cdr (assoc 'ELO dados)))))
  (if has_trafo_R
    (setq trafo_txt_R
      (strcat "TR - 3 - " (cdr (assoc 'POT_R dados)) "kVA")))
  (if has_chave_R
    (setq chave_txt_R
      (strcat (cdr (assoc 'QTD_R dados)) " - 100A - " (cdr (assoc 'ELO_R dados)))))

  (setq nodes_I '()  extra_blocks_I '()  extra_blocks_R '())
  (if (wcmatch desc_I "*-N[1234]*,*-B[1234]*,*-CE*,*-T*,*-U*,*-R[1234]*")
    (setq nodes_I (append nodes_I '("NO_MT"))))
  (if (wcmatch desc_I "*-S*,*-SI*,*-BI*,*-RA*")
    (setq nodes_I (append nodes_I '("NO_BT"))))
  (setq only_bt     (and (member "NO_BT" nodes_I) (not (member "NO_MT" nodes_I))))
  (setq draw_nodes_I (if only_bt '("NO_MT") nodes_I))

  (if (= (cdr (assoc 'TERRA dados)) 1)
    (setq extra_blocks_I (append extra_blocks_I '("TERRA3_I"))))
  (if (not only_bt)
    (cond
      ((and has_trafo_I has_chave_I)
       (setq extra_blocks_I (append extra_blocks_I '("TRAFO_CH_I"))))
      (has_trafo_I
       (setq extra_blocks_I (append extra_blocks_I '("TRAFO_I"))))
      (has_chave_I
       (setq extra_blocks_I (append extra_blocks_I '("CHAVE_I"))))))
  (cond
    ((= (cdr (assoc 'PR dados)) "PRMT")
     (setq extra_blocks_I (append extra_blocks_I '("PRMT_I"))))
    ((= (cdr (assoc 'PR dados)) "PRBT")
     (setq extra_blocks_I (append extra_blocks_I '("PRBT_I"))))
    ((= (cdr (assoc 'PR dados)) "Ambos")
     (setq extra_blocks_I (append extra_blocks_I '("PRMT_I" "PRBT_I")))))
  (if (= (cdr (assoc 'BASE dados)) 1)
    (setq extra_blocks_I (append extra_blocks_I '("BASE_MP"))))

  (cond
    ((and has_trafo_R has_chave_R)
     (setq extra_blocks_R (append extra_blocks_R '("TRAFO_CH_R"))))
    (has_trafo_R
     (setq extra_blocks_R (append extra_blocks_R '("TRAFO_R"))))
    (has_chave_R
     (setq extra_blocks_R (append extra_blocks_R '("CHAVE_R")))))

  (if (or has_trafo_I has_chave_I has_trafo_R has_chave_R)
    (setq base_ang (/ pi 2.0))
    (setq base_ang (* pi 1.5)))
  (setq offset_dist (if only_bt 2.2033 0.0))

  (setq p1 (list (cdr (assoc 'X dados)) (cdr (assoc 'Y dados)) 0.0))
  (setq final_p1_I (polar p1 (- ang_rad base_ang) offset_dist))
  (setq final_p1_R
    (if (= tipo "S")
      (polar final_p1_I ang_rad 3.0)
      final_p1_I))
  (setq ref_pt (if (= tipo "R") final_p1_R final_p1_I))

  (if (or (= tipo "R") (= tipo "S"))
    (progn
      (entmake (list '(0 . "INSERT") '(8 . "0") (cons 2 "POSTE_R")
                     (cons 10 final_p1_R)
                     (cons 50 (if (= tipo "S") (+ ang_rad (/ pi 2.0)) ang_rad))))
      (foreach b extra_blocks_R
        (if (tblsearch "BLOCK" b)
          (entmake (list '(0 . "INSERT") '(8 . "0") (cons 2 b)
                         (cons 10 final_p1_R)
                         (cons 50 (if (= tipo "S") (+ ang_rad (/ pi 2.0)) ang_rad))))))))

  (if (or (= tipo "I") (= tipo "S"))
    (progn
      (entmake (list '(0 . "INSERT") '(8 . "0") (cons 2 "POSTE_I")
                     (cons 10 final_p1_I) (cons 50 ang_rad)))
      (foreach b extra_blocks_I
        (if (tblsearch "BLOCK" b)
          (entmake (list '(0 . "INSERT") '(8 . "0") (cons 2 b)
                         (cons 10 final_p1_I) (cons 50 ang_rad)))))
      (foreach b draw_nodes_I
        (if (tblsearch "BLOCK" b)
          (entmake (list '(0 . "INSERT") '(8 . "0") (cons 2 b)
                         (cons 10 p1) (cons 50 ang_rad)))))))

  (setq blocks_data '())
  (if (or (= tipo "I") (= tipo "S"))
    (progn
      (setq texts_list_I (if has_prbt_I (list "INST. PRBT") nil))
      (setq texts_list_I (append texts_list_I (list desc_I)))
      (if has_trafo_I (setq texts_list_I (append texts_list_I (list trafo_txt_I))))
      (if has_chave_I (setq texts_list_I (append texts_list_I (list chave_txt_I))))
      (foreach t_str texts_list_I
        (setq blocks_data (append blocks_data (list (list t_str "I")))))))
  (if (or (= tipo "R") (= tipo "S"))
    (progn
      (setq texts_list_R (list desc_R))
      (if has_trafo_R (setq texts_list_R (append texts_list_R (list trafo_txt_R))))
      (if has_chave_R (setq texts_list_R (append texts_list_R (list chave_txt_R))))
      (foreach t_str texts_list_R
        (setq blocks_data (append blocks_data (list (list t_str "R")))))))

  (setq lado    (if (>= off_x 0.0) "R" "L")
        justify (if (= lado "R") 4 6)
        base_X  (+ (car  ref_pt) off_x)
        base_Y  (+ (cadr ref_pt) off_y)
        cur_Y   base_Y)

  (foreach b_data blocks_data
    (setq t_str (nth 0 b_data)
          style (nth 1 b_data))
    (entmake (list '(0 . "MTEXT") '(100 . "AcDbEntity") '(100 . "AcDbMText")
                   '(8 . "0")
                   (cons 10 (list base_X cur_Y (caddr ref_pt)))
                   (cons 40 txtH) '(41 . 0.0) (cons 71 justify)
                   (cons 1 t_str) (cons 62 (if (= style "I") 1 8))))
    (setq ent_txt (entlast)
          vla_obj (vlax-ename->vla-object ent_txt))
    (vla-getboundingbox vla_obj 'minpt 'maxpt)
    (setq min_l (vlax-safearray->list minpt)
          max_l (vlax-safearray->list maxpt))
    (if (= style "I")
      (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
                     '(8 . "0") '(90 . 4) '(70 . 1) (cons 62 1)
                     (cons 10 (list (- (car min_l) pad_h) (- (cadr min_l) pad_v)))
                     (cons 10 (list (+ (car max_l) pad_h) (- (cadr min_l) pad_v)))
                     (cons 10 (list (+ (car max_l) pad_h) (+ (cadr max_l) pad_v)))
                     (cons 10 (list (- (car min_l) pad_h) (+ (cadr max_l) pad_v))))))
    (if (= style "R")
      (entmake (list '(0 . "LINE") '(8 . "0")
                     (cons 10 (list (- (car min_l) pad_risco)
                                    (/ (+ (cadr min_l) (cadr max_l)) 2.0)))
                     (cons 11 (list (+ (car max_l) pad_risco)
                                    (/ (+ (cadr min_l) (cadr max_l)) 2.0)))
                     (cons 62 8))))
    (setq cur_Y (- (cadr min_l) pad_v box_gap pad_v (/ txtH 2.0))))

  T)


;;; ============================================================
;;; SECAO CABOS — parse, indices e insercao
;;; ============================================================

(defun prj-detectar-indices-cabo (hdr / i result col)
  (setq i 0  result '())
  (foreach col hdr
    (setq col (strcase col))
    (cond
      ((= col "REDE")      (setq result (append result (list (cons 'REDE i)))))
      ((= col "TIPO")      (setq result (append result (list (cons 'TIPO i)))))
      ((or (= col "ORIGEM_X")  (= col "ORI_X") (= col "OX"))
                           (setq result (append result (list (cons 'OX i)))))
      ((or (= col "ORIGEM_Y")  (= col "ORI_Y") (= col "OY"))
                           (setq result (append result (list (cons 'OY i)))))
      ((or (= col "DESTINO_X") (= col "DST_X") (= col "DX"))
                           (setq result (append result (list (cons 'DX i)))))
      ((or (= col "DESTINO_Y") (= col "DST_Y") (= col "DY"))
                           (setq result (append result (list (cons 'DY i)))))
      ((or (= col "CONDUTOR_I") (= col "COND_I") (= col "CI"))
                           (setq result (append result (list (cons 'CI i)))))
      ((or (= col "FASES_I") (= col "FASE_I") (= col "FI"))
                           (setq result (append result (list (cons 'FI i)))))
      ((or (= col "CONDUTOR_R") (= col "COND_R") (= col "CR"))
                           (setq result (append result (list (cons 'CR i)))))
      ((or (= col "FASES_R") (= col "FASE_R") (= col "FR"))
                           (setq result (append result (list (cons 'FR i)))))
      ((or (= col "DIST") (= col "DISTANCIA"))
                           (setq result (append result (list (cons 'DIST i))))))
    (setq i (1+ i)))
  result)

(defun prj-parse-cabo (campos idx / f g)
  (defun f (k) (prj-field campos (cdr (assoc k idx))))
  (defun g (k) (prj-atof-br (f k)))
  (list
    (cons 'REDE      (strcase (f 'REDE)))
    (cons 'TIPO      (strcase (f 'TIPO)))
    (cons 'ORIGEM_X  (g 'OX))
    (cons 'ORIGEM_Y  (g 'OY))
    (cons 'DESTINO_X (g 'DX))
    (cons 'DESTINO_Y (g 'DY))
    (cons 'CONDUTOR_I (f 'CI))
    (cons 'FASES_I    (f 'FI))
    (cons 'CONDUTOR_R (f 'CR))
    (cons 'FASES_R    (f 'FR))
    (cons 'DIST       (f 'DIST))))

(defun prj-inserir-cabo (dados
                          / rede tipo
                            ox oy dx dy
                            cond_i fase_i cond_r fase_r dist_str
                            p1 p2 ang_orig ang
                            cor ltype desc fase txt
                            midPt off txtPt txtH pad pad_risco
                            char_w line_sp
                            max_len cur_len idx char lines_len num_linhas
                            total_h total_w
                            dx_left dx_right pA pB pC pD
                            i top_offset w_i y_offset_i C_i pR1 pR2
                            ent_cab vla_cab min_cab max_cab mid_y_cab)

  (setq txtH      1.5
        pad       0.40
        pad_risco 0.15
        char_w    (* 1.5 0.72)
        line_sp   (* 1.5 1.6))

  (setq rede    (cdr (assoc 'REDE      dados))
        tipo    (cdr (assoc 'TIPO      dados))
        ox      (cdr (assoc 'ORIGEM_X  dados))
        oy      (cdr (assoc 'ORIGEM_Y  dados))
        dx      (cdr (assoc 'DESTINO_X dados))
        dy      (cdr (assoc 'DESTINO_Y dados))
        cond_i  (cdr (assoc 'CONDUTOR_I dados))
        fase_i  (cdr (assoc 'FASES_I    dados))
        cond_r  (cdr (assoc 'CONDUTOR_R dados))
        fase_r  (cdr (assoc 'FASES_R    dados))
        dist_str (cdr (assoc 'DIST      dados)))

  (cond
    ((= tipo "I") (setq desc cond_i  fase fase_i))
    ((= tipo "R") (setq desc cond_r  fase fase_r))
    (T            (setq desc cond_i  fase fase_i)))

  (setq dist_str
    (if (and dist_str (/= dist_str "") (/= (prj-atof-br dist_str) 0.0))
      dist_str
      (itoa (fix (+ (distance (list ox oy) (list dx dy)) 0.5)))))

  (setq txt (strcat " " desc " " fase " " dist_str " m "))

  (while (vl-string-search "\\p" txt)
    (setq txt (vl-string-subst " \\P " "\\p" txt)))

  (setq cor   (if (= tipo "I") 1 8)
        ltype "Continuous")
  (if (= rede "MT")
    (cond ((tblsearch "ltype" "TRACEJADA") (setq ltype "TRACEJADA"))
          ((tblsearch "ltype" "DASHED")    (setq ltype "DASHED"))
          ((tblsearch "ltype" "HIDDEN")    (setq ltype "HIDDEN"))))

  (setq p1 (list ox oy 0.0)
        p2 (list dx dy 0.0))

  (entmake (list '(0 . "LINE") (cons 10 p1) (cons 11 p2) (cons 62 cor) (cons 6 ltype) '(48 . 1.0)))

  (setq ang_orig (angle p1 p2)
        ang      ang_orig)
  (if (and (> ang_orig (/ pi 2)) (<= ang_orig (* pi 1.5)))
    (setq ang (- ang pi)))

  (setq max_len 0  cur_len 0  idx 1  lines_len '())
  (while (<= idx (strlen txt))
    (setq char (substr txt idx 2))
    (if (= char "\\P")
      (progn
        (setq lines_len (append lines_len (list cur_len)))
        (if (> cur_len max_len) (setq max_len cur_len))
        (setq cur_len 0  idx (+ idx 2)))
      (progn (setq cur_len (1+ cur_len)  idx (1+ idx)))))
  (setq lines_len (append lines_len (list cur_len)))
  (if (> cur_len max_len) (setq max_len cur_len))

  (setq num_linhas (length lines_len)
        total_h    (+ txtH (* (1- num_linhas) line_sp))
        total_w    (* max_len char_w))

  (setq midPt (mapcar '(lambda (a b) (/ (+ a b) 2.0)) p1 p2)
        off   (+ 1.0 (/ total_h 2.0)))
  (if (and (> ang_orig (/ pi 2)) (<= ang_orig (* pi 1.5)))
    (setq txtPt (polar midPt (- ang (/ pi 2)) off))
    (setq txtPt (polar midPt (+ ang (/ pi 2)) off)))

  (entmake (list '(0 . "MTEXT") '(100 . "AcDbEntity") '(100 . "AcDbMText")
                 (cons 10 txtPt) (cons 40 txtH) (cons 41 0.0) (cons 71 5)
                 (cons 1 txt) (cons 50 ang) (cons 62 cor)))

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

  ;; Listra para cabo removendo: igual ao padrao dos postes (LINE simples, pontos no angulo do texto)
  (if (= tipo "R")
    (progn
      (setq i 0  top_offset (/ (* (1- num_linhas) line_sp) 2.0))
      (while (< i num_linhas)
        (setq w_i        (* (nth i lines_len) char_w)
              y_offset_i (- top_offset (* i line_sp))
              C_i        (polar txtPt (+ ang (/ pi 2)) y_offset_i)
              pR1        (polar C_i (+ ang pi) (+ (/ w_i 2.0) pad_risco))
              pR2        (polar C_i ang         (+ (/ w_i 2.0) pad_risco)))
        (entmake (list '(0 . "LINE") '(8 . "0")
                       (cons 10 pR1) (cons 11 pR2) (cons 62 cor)))
        (setq i (1+ i)))))

  T)


;;; ============================================================
;;; COMANDO PRINCIPAL: c:PROJETO_LOTE
;;; Lê projeto.csv unificado e insere postes + cabos em sequência.
;;; Sem dependência de DCL externo — entrada via linha de comando.
;;; ============================================================
(defun c:PROJETO_LOTE (/ v_csv_path off_x off_y ang_fallback
                         escala fator_cabo
                         dcl_path dcl_id dlg_result
                         f_handle linha campos
                         ;; postes
                         lista_dados lista_angs lista_angs_calc lista_angs_rede
                         segmentos_cabo mapa_coord_500
                         idx idx_tmp ang_rad ang_dxf_str dados dados_mod
                         num_pos_total num_pos_ok num_pos_erro
                         ;; cabos
                         hdr_cabo idx_map
                         num_cab_total num_cab_ok num_cab_erro
                         ;; compartilhado
                         err_msgs_pos err_msgs_cab
                         cabecalho_pulado continuar achou_postes achou_cabos
                         _msg _tmp_r)

  (vl-load-com)

  ;;; ============================================================
  ;;; INTERFACE GRAFICA — DCL gerado dinamicamente em arquivo temp
  ;;; ============================================================
  (setq dcl_path (strcat (getenv "TEMP") "\\prj_lote_dlg.dcl"))

  ;; Escreve o DCL no disco
  (setq _f (open dcl_path "w"))
  (write-line "prj_lote : dialog {" _f)
  (write-line "  label = \"PROJETO_LOTE — Configuracao\";" _f)
  (write-line "  : text { label = \"Escala de plotagem:\"; height = 1; }" _f)
  (write-line "  : radio_column {" _f)
  (write-line "    key = \"esc_col\";" _f)
  (write-line "    : radio_button { key = \"r1000\"; label = \"1:1000  (linha = distancia real)\"; }" _f)
  (write-line "    : radio_button { key = \"r500\";  label = \"1:500   (linha = dobro da distancia real)\"; }" _f)
  (write-line "  }" _f)
  (write-line "  spacer;" _f)
  (write-line "  : text { label = \"Offset da anotacao dos postes:\"; height = 1; }" _f)
  (write-line "  : row {" _f)
  (write-line "    : edit_box { label = \"Offset X\"; key = \"offx\"; edit_width = 8; } " _f)
  (write-line "    : edit_box { label = \"Offset Y\"; key = \"offy\"; edit_width = 8; }" _f)
  (write-line "  }" _f)
  (write-line "  spacer;" _f)
  (write-line "  : text { label = \"Angulo fallback (graus, usado sem cabos):\"; height = 1; }" _f)
  (write-line "  : edit_box { label = \"Angulo\"; key = \"angfb\"; edit_width = 8; }" _f)
  (write-line "  spacer;" _f)
  (write-line "  ok_cancel;" _f)
  (write-line "}" _f)
  (close _f)

  ;; Carrega e exibe o dialogo
  (setq dcl_id (load_dialog dcl_path))
  (if (< dcl_id 0)
    (progn (alert "Erro ao carregar dialogo interno.") (princ) (exit)))

  (if (not (new_dialog "prj_lote" dcl_id))
    (progn (alert "Erro ao criar dialogo.") (princ) (exit)))

  ;; Valores padrao
  (set_tile "r1000" "1")
  (set_tile "offx"  "3.0")
  (set_tile "offy"  "0.0")
  (set_tile "angfb" "90")

  ;; Coleta resultado ao confirmar
  (setq dlg_result (list "1000" "3.0" "0.0" "90"))

  (action_tile "accept"
    "(setq dlg_result (list
       (if (= (get_tile \"r500\") \"1\") \"500\" \"1000\")
       (get_tile \"offx\")
       (get_tile \"offy\")
       (get_tile \"angfb\")))
     (done_dialog 1)")

  (action_tile "cancel" "(done_dialog 0)")

  (setq _dlg_ok (start_dialog))
  (unload_dialog dcl_id)

  (if (= _dlg_ok 0)
    (progn (princ "\nCancelado.") (princ) (exit)))

  ;; Extrai valores do resultado
  (setq escala     (nth 0 dlg_result)
        off_x      (atof (nth 1 dlg_result))
        off_y      (atof (nth 2 dlg_result))
        ang_fallback (* (atof (nth 3 dlg_result)) (/ pi 180.0)))

  (setq fator_cabo (if (= escala "500") 2.0 1.0))
  (setq *prj-fator-cabo* fator_cabo)
  (princ (strcat "\nEscala: 1:" escala "  |  OffX=" (rtos off_x 2 2)
                 "  OffY=" (rtos off_y 2 2)
                 "  AngFallback=" (rtos (* ang_fallback (/ 180.0 pi)) 2 1) "deg"))

  ;;; --- selecionar arquivo CSV ---
  (setq v_csv_path (getfiled "Selecionar projeto.csv" "" "csv" 0))
  (if (not v_csv_path)
    (progn (princ "\nCancelado.") (princ) (exit)))

  (if (not (findfile v_csv_path))
    (progn (alert (strcat "Arquivo nao encontrado:\n" v_csv_path)) (exit)))


  ;;; ============================================================
  ;;; PASSO 1 — Ler seção [POSTES]
  ;;; ============================================================
  (setq f_handle (open v_csv_path "r"))
  (if (not f_handle)
    (progn (alert "Nao foi possivel abrir o arquivo.") (exit)))

  (setq lista_dados     '()
        err_msgs_pos    '()
        segmentos_cabo  '()
        num_pos_total   0
        num_pos_erro    0
        cabecalho_pulado nil
        achou_postes    nil
        continuar       T)

  ;; Avanca ate [POSTES]
  (while (and continuar (not achou_postes))
    (setq linha (read-line f_handle))
    (cond
      ((eq linha nil) (setq continuar nil))
      ((= (prj-trim linha) "") nil)
      ((= (substr (prj-trim linha) 1 1) "[")
       (if (= (strcase (prj-trim linha)) "[POSTES]")
         (setq achou_postes T)
         nil))
      ;; CSV sem marcador: trata primeira linha nao-vazia como cabecalho
      (T (setq achou_postes T  cabecalho_pulado T))))

  ;; Le dados de postes ate [CABOS] ou EOF
  (setq continuar T)
  (while continuar
    (setq linha (read-line f_handle))
    (if (eq linha nil)
      (setq continuar nil)
      (progn
        (setq linha (prj-trim linha))
        (cond
          ((= linha "") nil)
          ;; [CABOS] ou outro marcador: para leitura de postes
          ((= (substr linha 1 1) "[") (setq continuar nil))
          ;; pula cabecalho
          ((not cabecalho_pulado) (setq cabecalho_pulado T))
          ;; dado de poste
          (T
           (setq num_pos_total (1+ num_pos_total))
           (setq campos (prj-split-csv linha))
           (if (< (length campos) 3)
             (progn
               (setq num_pos_erro (1+ num_pos_erro))
               (setq err_msgs_pos (append err_msgs_pos
                 (list (strcat "P" (itoa num_pos_total) ": campos insuficientes.")))))
             (progn
               (setq dados (prj-parse-poste campos))
               (if (not (member (cdr (assoc 'TIPO dados)) '("I" "R" "S")))
                 (progn
                   (setq num_pos_erro (1+ num_pos_erro))
                   (setq err_msgs_pos (append err_msgs_pos
                     (list (strcat "P" (itoa num_pos_total)
                                   ": TIPO invalido (" (cdr (assoc 'TIPO dados)) ").")))))
                 (setq lista_dados (append lista_dados (list dados))))))))))
  )

  ;; Verificar se [CABOS] foi encontrado (ultima linha lida foi "[CABOS]")
  ;; Se sim, le os cabos para extrair segmentos para calculo de angulo
  ;; Detecta se a ultima linha lida era [CABOS]
  ;; Re-lê o arquivo a partir do [CABOS] para os segmentos
  ;; (mais simples: continua lendo o f_handle que parou no marcador)

  ;;; ============================================================
  ;;; PASSO 2 — Ler seção [CABOS] para calcular ângulos e guardar dados
  ;;; ============================================================
  ;; f_handle está posicionado logo após [CABOS] (ou a linha que parou a leitura)
  ;; Precisamos confirmar que a ultima linha lida foi de fato [CABOS].
  ;; Como o loop parou ao detectar "[", a leitura ja passou dessa linha.
  ;; Vamos re-abrir o arquivo para encontrar [CABOS] de forma segura.
  (close f_handle)

  (setq f_handle      (open v_csv_path "r")
        hdr_cabo      nil
        idx_map       nil
        achou_cabos   nil
        continuar     T
        num_cab_total 0
        num_cab_ok    0
        num_cab_erro  0
        err_msgs_cab  '())

  (while (and continuar (not achou_cabos))
    (setq linha (read-line f_handle))
    (cond
      ((eq linha nil) (setq continuar nil))
      ((= (prj-trim linha) "") nil)
      ((and (= (substr (prj-trim linha) 1 1) "[")
            (= (strcase (prj-trim linha)) "[CABOS]"))
       (setq achou_cabos T))
      (T nil)))

  (if achou_cabos
    (progn
      ;; Le cabecalho dos cabos
      (setq linha (read-line f_handle))
      (if linha
        (progn
          (setq hdr_cabo (mapcar 'strcase (prj-split-csv (prj-trim linha))))
          (setq idx_map  (prj-detectar-indices-cabo hdr_cabo)))
        (setq achou_cabos nil))))

  ;; Le linhas de cabos: guarda segmentos (para angulo) e todos os dados (para insercao)
  (setq lista_cabos '()  continuar T)
  (if (and achou_cabos idx_map
           (assoc 'OX idx_map) (assoc 'OY idx_map)
           (assoc 'DX idx_map) (assoc 'DY idx_map))
    (while continuar
      (setq linha (read-line f_handle))
      (if (eq linha nil)
        (setq continuar nil)
        (progn
          (setq linha (prj-trim linha))
          (cond
            ((= linha "") nil)
            ((= (substr linha 1 1) "[") (setq continuar nil))
            (T
             (setq campos (prj-split-csv linha))
             (if (>= (length campos) 6)
               (progn
                 (setq dados (prj-parse-cabo campos idx_map))
                 ;; guarda segmento para calculo de angulo
                 (setq ox (cdr (assoc 'ORIGEM_X  dados))
                       oy (cdr (assoc 'ORIGEM_Y  dados))
                       dx (cdr (assoc 'DESTINO_X dados))
                       dy (cdr (assoc 'DESTINO_Y dados)))
                 (if (not (and (= ox 0.0) (= oy 0.0) (= dx 0.0) (= dy 0.0)))
                   (setq segmentos_cabo (append segmentos_cabo
                                          (list (list ox oy dx dy)))))
                 ;; guarda dados para insercao posterior
                 (if (member (cdr (assoc 'TIPO dados)) '("I" "R" "S"))
                   (progn
                     (setq num_cab_total (1+ num_cab_total))
                     (setq lista_cabos (append lista_cabos (list dados))))
                   (progn
                     (setq num_cab_erro (1+ num_cab_erro))
                     (setq err_msgs_cab (append err_msgs_cab
                       (list (strcat "C" (itoa (1+ (length lista_cabos)))
                                     ": TIPO invalido."))))))))))))))

  (close f_handle)


  ;;; ============================================================
  ;;; PASSO 3 — Calcular ângulos dos postes
  ;;; ============================================================
  (setq lista_angs_calc (prj-calcular-angulos lista_dados ang_fallback))

  (setq lista_angs_rede
    (if segmentos_cabo
      (prj-angulos-pela-rede lista_dados segmentos_cabo lista_angs_calc 1.0)
      lista_angs_calc))

  ;; Mescla: DXF > rede > sequencia
  (setq lista_angs '()  idx_tmp 0)
  (foreach dados lista_dados
    (setq ang_dxf_str (cdr (assoc 'ANGULO_DXF dados)))
    (if (and ang_dxf_str (/= ang_dxf_str ""))
      (setq lista_angs (append lista_angs
                          (list (* (prj-atof-br ang_dxf_str) (/ pi 180.0)))))
      (setq lista_angs (append lista_angs
                          (list (nth idx_tmp lista_angs_rede)))))
    (setq idx_tmp (1+ idx_tmp)))


  ;;; ============================================================
  ;;; PASSO 3b — Escala 1:500: multiplica toda a geometria por 2
  ;;; Usa o primeiro poste como ancora para nao deslocar para longe da origem.
  ;;; ============================================================
  (if (and (= escala "500") lista_dados)
    (progn
      (setq _anc_x (cdr (assoc 'X (car lista_dados)))
            _anc_y (cdr (assoc 'Y (car lista_dados))))
      ;; Reescala postes
      (setq lista_dados
        (mapcar
          '(lambda (d)
             (subst (cons 'X (+ _anc_x (* fator_cabo (- (cdr (assoc 'X d)) _anc_x))))
                    (assoc 'X d)
               (subst (cons 'Y (+ _anc_y (* fator_cabo (- (cdr (assoc 'Y d)) _anc_y))))
                      (assoc 'Y d) d)))
          lista_dados))
      ;; Reescala segmentos de cabo (para calculo de angulo ja foi feito, mas
      ;; reescala lista_cabos para insercao correta das linhas)
      (setq lista_cabos
        (mapcar
          '(lambda (d)
             (subst (cons 'ORIGEM_X  (+ _anc_x (* fator_cabo (- (cdr (assoc 'ORIGEM_X  d)) _anc_x))))
                    (assoc 'ORIGEM_X d)
               (subst (cons 'ORIGEM_Y  (+ _anc_y (* fator_cabo (- (cdr (assoc 'ORIGEM_Y  d)) _anc_y))))
                      (assoc 'ORIGEM_Y d)
                 (subst (cons 'DESTINO_X (+ _anc_x (* fator_cabo (- (cdr (assoc 'DESTINO_X d)) _anc_x))))
                        (assoc 'DESTINO_X d)
                   (subst (cons 'DESTINO_Y (+ _anc_y (* fator_cabo (- (cdr (assoc 'DESTINO_Y d)) _anc_y))))
                          (assoc 'DESTINO_Y d) d)))))
          lista_cabos))))

  ;;; ============================================================
  ;;; PASSO 4 — Inserir postes
  ;;; ============================================================
  (setq idx    0
        num_pos_ok 0)

  (foreach dados lista_dados
    (setq ang_rad (nth idx lista_angs)
          idx     (1+ idx))
    (if (vl-catch-all-error-p
          (vl-catch-all-apply 'prj-inserir-poste
            (list dados off_x off_y ang_rad)))
      (progn
        (setq num_pos_erro (1+ num_pos_erro))
        (setq err_msgs_pos (append err_msgs_pos
          (list (strcat "P" (itoa idx) ": erro na insercao.")))))
      (setq num_pos_ok (1+ num_pos_ok))))


  ;;; ============================================================
  ;;; PASSO 5 — Inserir cabos
  ;;; ============================================================
  (foreach dados lista_cabos
    (if (vl-catch-all-error-p
          (vl-catch-all-apply 'prj-inserir-cabo (list dados)))
      (progn
        (setq num_cab_erro (1+ num_cab_erro))
        (setq err_msgs_cab (append err_msgs_cab
          (list (strcat "C" (itoa (1+ num_cab_ok)) ": erro na insercao.")))))
      (setq num_cab_ok (1+ num_cab_ok))))


  ;;; ============================================================
  ;;; PASSO 6 — Relatório final
  ;;; ============================================================
  (setq _msg (strcat
    "Insercao concluida!\n"
    "  Postes inseridos : " (itoa num_pos_ok)   "\n"
    "  Cabos  inseridos : " (itoa num_cab_ok)   "\n"
    "  Erros  postes    : " (itoa num_pos_erro) "\n"
    "  Erros  cabos     : " (itoa num_cab_erro)))

  (if (or err_msgs_pos err_msgs_cab)
    (progn
      (setq _msg (strcat _msg "\n\nDetalhes:"))
      (foreach e (append
                   (if (> (length err_msgs_pos) 5)
                     (append (list (nth 0 err_msgs_pos) (nth 1 err_msgs_pos)
                                   (nth 2 err_msgs_pos) (nth 3 err_msgs_pos)
                                   (nth 4 err_msgs_pos))
                             (list (strcat "... +" (itoa (- (length err_msgs_pos) 5)) " postes.")))
                     err_msgs_pos)
                   (if (> (length err_msgs_cab) 5)
                     (append (list (nth 0 err_msgs_cab) (nth 1 err_msgs_cab)
                                   (nth 2 err_msgs_cab) (nth 3 err_msgs_cab)
                                   (nth 4 err_msgs_cab))
                             (list (strcat "... +" (itoa (- (length err_msgs_cab) 5)) " cabos.")))
                     err_msgs_cab))
        (setq _msg (strcat _msg "\n  " e)))))

  (alert _msg)
  (princ (strcat "\nPROJETO_LOTE: " (itoa num_pos_ok) " postes + "
                 (itoa num_cab_ok) " cabos inseridos."))
  (princ))
