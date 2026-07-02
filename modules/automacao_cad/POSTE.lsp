;; POSTE.lsp - Compativel com nanoCAD 5 e AutoCAD
;; Script unificado (LSP + DCL) com Sistema de Perfis Blindado (CSV-like)

;;; =========================================================================
;;; FUNCOES AUXILIARES PARA PASTAS
;;; =========================================================================
(defun get-config-folder ( / dir )
  (setq dir (strcat (getenv "LOCALAPPDATA") "\\NanoCAD_Scripts_CAD"))
  (vl-mkdir dir) ;; Cria a pasta se ela nao existir
  dir
)

(defun get-desc-filepath ()
  (strcat (get-config-folder) "\\poste_descricoes.txt")
)

(defun get-preset-filepath ()
  (strcat (get-config-folder) "\\poste_estados.txt")
)

;;; =========================================================================
;;; SISTEMA BLINDADO DE TEXTO (Substitui LISP nativo para evitar bugs no nanoCAD)
;;; =========================================================================
(defun split-string ( str delim / pos lst delim_len )
  (setq delim_len (strlen delim) lst '())
  (while (setq pos (vl-string-search delim str))
    (setq lst (append lst (list (substr str 1 pos))))
    (setq str (substr str (+ pos 1 delim_len)))
  )
  (append lst (list str))
)

(defun join-strings ( lst delim / str )
  (setq str (car lst))
  (foreach item (cdr lst)
    (setq str (strcat str delim item))
  )
  str
)

(defun sanitize-str ( str )
  (while (vl-string-search "|" str)
    (setq str (vl-string-subst "-" "|" str))
  )
  str
)

;;; --- MANIPULACAO DE DESCRICOES ---
(defun load-descricoes ( / f line lst )
  (setq lst '("Selecione..."))
  (if (setq f (open (get-desc-filepath) "r"))
    (progn
      (while (setq line (read-line f))
        (if (and (/= (vl-string-trim " " line) "") (not (member line lst)))
          (setq lst (append lst (list line)))
        )
      )
      (close f)
    )
  )
  lst
)

(defun save-descricao ( desc / f lst )
  (setq desc (strcase (vl-string-trim " " desc)))
  (if (/= desc "")
    (progn
      (setq lst (load-descricoes))
      (if (not (member desc lst))
        (progn
          (if (setq f (open (get-desc-filepath) "a"))
            (progn
              (write-line desc f)
              (close f)
              (alert (strcat "Descricao '" desc "' salva com sucesso!"))
              T
            )
            (progn (alert "Erro: Nao foi possivel salvar no arquivo.") nil)
          )
        )
        (progn (alert "Esta descricao ja existe na lista salva.") nil)
      )
    )
    (progn (alert "Nenhum texto foi inserido na descricao!") nil)
  )
)

(defun remove-descricao ( desc / f lst new_lst )
  (setq desc (strcase (vl-string-trim " " desc)))
  (if (and (/= desc "") (/= desc "SELECIONE..."))
    (progn
      (setq lst (load-descricoes) new_lst '())
      (foreach v lst
        (if (and (/= (strcase v) desc) (/= v "Selecione..."))
          (setq new_lst (append new_lst (list v)))
        )
      )
      (if (setq f (open (get-desc-filepath) "w"))
        (progn
          (foreach v new_lst (write-line v f))
          (close f)
          (alert (strcat "Descricao '" desc "' removida com sucesso!"))
          T
        )
        (progn (alert "Erro: Nao foi possivel editar o arquivo.") nil)
      )
    )
    (progn (alert "Selecione uma descricao valida para remover.") nil)
  )
)

;;; --- MANIPULACAO DE PERFIS (PRESETS - SISTEMA CSV-LIKE) ---
(defun save-preset ( name / lines new_lines f vars_str line split_line )
  (setq name (vl-string-trim " " (sanitize-str name)))
  (if (= name "")
    (progn (alert "Nome do perfil invalido!") nil)
    (progn
      ;; Coleta tudo como texto puro separado por barras |
      (setq vars_str
        (join-strings
          (list
            name
            (sanitize-str (if (get_tile "desc_I") (get_tile "desc_I") ""))
            (sanitize-str (if (get_tile "desc_R") (get_tile "desc_R") ""))
            (cond ((= (get_tile "tipo_S") "1") "S") ((= (get_tile "tipo_R") "1") "R") (T "I"))
            (if (get_tile "trafo_I") (get_tile "trafo_I") "0")
            (if (get_tile "pot_I") (get_tile "pot_I") "0")
            (if (get_tile "chave_I") (get_tile "chave_I") "0")
            (if (get_tile "elo_I") (get_tile "elo_I") "0")
            (if (get_tile "terra_I") (get_tile "terra_I") "0")
            (if (get_tile "base_I") (get_tile "base_I") "0")
            (if (get_tile "trafo_R") (get_tile "trafo_R") "0")
            (if (get_tile "pot_R") (get_tile "pot_R") "0")
            (if (get_tile "chave_R") (get_tile "chave_R") "0")
            (if (get_tile "elo_R") (get_tile "elo_R") "0")
            (if (= (get_tile "qty_I_3") "1") "3" "1")
            (if (= (get_tile "qty_R_3") "1") "3" "1")
            (cond ((= (get_tile "pr_PRMT") "1") "PRMT") ((= (get_tile "pr_PRBT") "1") "PRBT") ((= (get_tile "pr_Ambos") "1") "Ambos") (T "Nenhum"))
            (if (= (get_tile "esf_I_m") "1") "m" "M")
            (if (= (get_tile "esf_R_m") "1") "m" "M")
          )
          "|"
        )
      )

      ;; Le os perfis existentes
      (setq lines '())
      (if (setq f (open (get-preset-filepath) "r"))
        (progn
          (while (setq line (read-line f))
            (if (and line (/= (vl-string-trim " " line) ""))
              (setq lines (append lines (list line)))
            )
          )
          (close f)
        )
      )

      ;; Remove versoes antigas do mesmo nome
      (setq new_lines '())
      (foreach line lines
        (setq split_line (split-string line "|"))
        (if (and (> (length split_line) 0) (/= (car split_line) name))
          (setq new_lines (append new_lines (list line)))
        )
      )

      ;; Salva tudo novamente
      (setq new_lines (append new_lines (list vars_str)))
      (if (setq f (open (get-preset-filepath) "w"))
        (progn
          (foreach line new_lines (write-line line f))
          (close f)
          (alert (strcat "Perfil '" name "' salvo com sucesso!"))
          T
        )
        (progn (alert "Erro ao salvar perfil no arquivo!") nil)
      )
    )
  )
)

(defun remove-preset ( name / lines new_lines f line split_line )
  (setq name (vl-string-trim " " name))
  (if (or (= name "") (= name "Selecione..."))
    (progn (alert "Selecione um perfil valido para remover.") nil)
    (progn
      (setq lines '())
      (if (setq f (open (get-preset-filepath) "r"))
        (progn
          (while (setq line (read-line f))
            (if (and line (/= (vl-string-trim " " line) ""))
              (setq lines (append lines (list line)))
            )
          )
          (close f)
        )
      )

      (setq new_lines '())
      (foreach line lines
        (setq split_line (split-string line "|"))
        (if (and (> (length split_line) 0) (/= (car split_line) name))
          (setq new_lines (append new_lines (list line)))
        )
      )

      (if (setq f (open (get-preset-filepath) "w"))
        (progn
          (foreach line new_lines (write-line line f))
          (close f)
          (alert (strcat "Perfil '" name "' removido!"))
          T
        )
        (progn (alert "Erro ao remover perfil do arquivo!") nil)
      )
    )
  )
)

;;; =========================================================================
;;; COMANDO PRINCIPAL
;;; =========================================================================
(defun c:POSTE (/ desc_I desc_R tipo txtH pad_v pad_h pad_risco char_w line_sp ang box_gap
                  p1 p2 p3 has_trafo_I has_chave_I has_prbt_I extra_blocks_I nodes_I 
                  draw_nodes_I texts_list_I trafo_txt_I chave_txt_I has_trafo_R 
                  has_chave_R extra_blocks_R texts_list_R trafo_txt_R chave_txt_R
                  blocks_data style base_ang offset_dist only_bt first_run last_ang 
                  last_vec_X last_vec_Y lado justify insertion_loop pt_input ref_pt 
                  final_p1_I final_p1_R base_X base_Y cur_Y t_str ent_txt vla_obj 
                  minpt maxpt min_l max_l dcl_id dlg_result dcl_file 
                  v_desc_I v_desc_R v_tipo v_terra_I v_trafo_I v_pot_I v_chave_I 
                  v_qty_I v_elo_I v_esf_I v_pr_I v_base_I v_trafo_R v_pot_R v_chave_R 
                  v_qty_R v_elo_R v_esf_R v_coord_X v_coord_Y coord_pt use_coord 
                  pot_list elo_list pot_I_str pot_R_str elo_I_str elo_R_str main_loop b 
                  desc_list preset_list update-desc-lists update-preset-lists f draw_poste_I draw_poste_R
                  bloco_poste_I bloco_poste_R v_selected_preset val)

  (vl-load-com)

  ;; Funcoes de Interface
  (defun update-desc-lists ()
    (setq desc_list (load-descricoes))
    (start_list "list_desc_I") (foreach v desc_list (add_list v)) (end_list)
    (start_list "list_desc_R") (foreach v desc_list (add_list v)) (end_list)
  )

  (defun update-preset-lists ( / f line split_line )
    (setq preset_list (list "Selecione..."))
    (if (setq f (open (get-preset-filepath) "r"))
      (progn
        (while (setq line (read-line f))
          (if (and line (/= (vl-string-trim " " line) ""))
            (progn
              (setq split_line (split-string line "|"))
              (if (> (length split_line) 0)
                (setq preset_list (append preset_list (list (car split_line))))
              )
            )
          )
        )
        (close f)
      )
    )
    (start_list "list_presets") (foreach v preset_list (add_list v)) (end_list)
  )

  (defun apply-preset-to-vars ( name / f line split_line found vars )
    (if (setq f (open (get-preset-filepath) "r"))
      (progn
        (while (and (not found) (setq line (read-line f)))
          (setq split_line (split-string line "|"))
          (if (and (> (length split_line) 0) (= (car split_line) name))
            (setq found split_line)
          )
        )
        (close f)
      )
    )
    (if found
      (progn
        (setq vars (cdr found)) ; remove name
        (if (>= (length vars) 16)
          (progn
            (setq v_desc_I  (nth 0 vars)
                  v_desc_R  (nth 1 vars)
                  v_tipo    (nth 2 vars)
                  v_trafo_I (atoi (nth 3 vars))
                  v_pot_I   (atoi (nth 4 vars))
                  v_chave_I (atoi (nth 5 vars))
                  v_elo_I   (atoi (nth 6 vars))
                  v_terra_I (atoi (nth 7 vars))
                  v_base_I  (atoi (nth 8 vars))
                  v_trafo_R (atoi (nth 9 vars))
                  v_pot_R   (atoi (nth 10 vars))
                  v_chave_R (atoi (nth 11 vars))
                  v_elo_R   (atoi (nth 12 vars))
                  v_qty_I   (nth 13 vars)
                  v_qty_R   (nth 14 vars)
                  v_pr_I    (nth 15 vars))
            ;; Compatibilidade com perfis mais novos contendo Esforço
            (if (>= (length vars) 18)
              (setq v_esf_I (nth 16 vars)
                    v_esf_R (nth 17 vars))
              (setq v_esf_I "M" v_esf_R "M")
            )
          )
        )
      )
    )
  )

  ;;; CONFIGURACOES VISUAIS
  (setq txtH      1.5
        pad_v     0.40
        pad_h     0.50
        pad_risco 0.20
        char_w    (* 1.5 0.72)
        line_sp   (* 1.5 1.6)
        ang       0.0
        box_gap   0.30)

  ;;; LISTAS
  (setq pot_list (list "25" "30" "45" "75" "112,5" "150" "225" "300"))
  (setq elo_list (list "1H" "2H" "3H" "5H" "6K" "10K" "12K"))

  ;;; VALORES INICIAIS
  (setq v_desc_I "" v_desc_R "" v_coord_X "" v_coord_Y "" v_tipo "I"
        v_trafo_I 0 v_pot_I 4 v_chave_I 0 v_qty_I "1" v_elo_I 0 v_terra_I 0 v_esf_I "M"
        v_base_I 0 v_trafo_R 0 v_pot_R 4 v_chave_R 0 v_qty_R "1" v_elo_R 0 v_esf_R "M"
        v_pr_I "Nenhum" v_selected_preset "")

  ;;; =========================================================================
  ;;; GERACAO DINAMICA DO ARQUIVO DCL TEMPORARIO
  ;;; =========================================================================
  (setq dcl_file (vl-filename-mktemp "poste_temp.dcl"))
  (setq f (open dcl_file "w"))
  (write-line "poste_dlg : dialog {" f)
  (write-line "  label = \"Poste - Configuracao\"; width = 60;" f)
  (write-line "  : text { label = \"--- PERFIS SALVOS (PRESETS) ---\"; width = 50; }" f)
  (write-line "  : row { : edit_box { key = \"preset_name\"; width = 16; } : popup_list { key = \"list_presets\"; width = 18; } : button { key = \"btn_save_preset\"; label = \"Salvar\"; width = 8; } : button { key = \"btn_rem_preset\"; label = \"Remover\"; width = 8; } }" f)
  (write-line "  : spacer { height = 1; }" f)
  (write-line "  : text { label = \"--- IDENTIFICACAO ---\"; width = 50; }" f)
  (write-line "  : row { : text { label = \"Descricao (Inst/Base):\"; width = 22; } : edit_box { key = \"desc_I\"; width = 24; } }" f)
  (write-line "  : row { : spacer { width = 22; } : popup_list { key = \"list_desc_I\"; width = 18; } : button { key = \"btn_save_I\"; label = \"Salvar\"; width = 8; } : button { key = \"btn_rem_I\"; label = \"Remover\"; width = 8; } }" f)
  (write-line "  : row { : text { label = \"Operacao:\"; width = 22; } : radio_row { : radio_button { key = \"tipo_I\"; label = \"Instalando\"; } : radio_button { key = \"tipo_R\"; label = \"Removendo\"; } : radio_button { key = \"tipo_S\"; label = \"Substituindo\"; } } }" f)
  (write-line "  : row { : text { label = \"Descricao (Rem):\"; width = 22; } : edit_box { key = \"desc_R\"; width = 24; } }" f)
  (write-line "  : row { : spacer { width = 22; } : popup_list { key = \"list_desc_R\"; width = 18; } : button { key = \"btn_save_R\"; label = \"Salvar\"; width = 8; } : button { key = \"btn_rem_R\"; label = \"Remover\"; width = 8; } }" f)
  (write-line "  : spacer { height = 1; }" f)
  (write-line "  : text { label = \"--- COORDENADA (opcional) ---\"; width = 50; }" f)
  (write-line "  : text { label = \"  Deixe em branco para clicar no desenho.\"; width = 50; }" f)
  (write-line "  : row { : text { label = \"  X:\"; width = 10; } : edit_box { key = \"coord_X\"; width = 18; } : text { label = \"  Y:\"; width = 10; } : edit_box { key = \"coord_Y\"; width = 18; } }" f)
  (write-line "  : spacer { height = 1; } : text { label = \"--- INSTALANDO ---\"; width = 50; }" f)
  (write-line "  : row { : text { label = \"Adicionar Terra?\"; width = 22; } : toggle { key = \"terra_I\"; label = \"\"; } }" f)
  (write-line "  : row { : text { label = \"Adicionar Trafo?\"; width = 22; } : toggle { key = \"trafo_I\"; label = \"\"; } }" f)
  (write-line "  : row { : text { label = \"  Potencia (kVA):\"; width = 22; } : popup_list { key = \"pot_I\"; width = 14; } }" f)
  (write-line "  : row { : text { label = \"Adicionar Chave?\"; width = 22; } : toggle { key = \"chave_I\"; label = \"\"; } }" f)
  (write-line "  : row { : text { label = \"  Quantidade:\"; width = 22; } : radio_row { : radio_button { key = \"qty_I_1\"; label = \"1\"; } : radio_button { key = \"qty_I_3\"; label = \"3\"; } } }" f)
  (write-line "  : row { : text { label = \"  Elo:\"; width = 22; } : popup_list { key = \"elo_I\"; width = 14; } }" f)
  (write-line "  : row { : text { label = \"  Esforco:\"; width = 22; } : radio_row { : radio_button { key = \"esf_I_M\"; label = \"Maior\"; } : radio_button { key = \"esf_I_m\"; label = \"Menor\"; } } }" f)
  (write-line "  : row { : text { label = \"Adicionar PR?\"; width = 22; } : radio_row { : radio_button { key = \"pr_PRMT\"; label = \"PRMT\"; } : radio_button { key = \"pr_PRBT\"; label = \"PRBT\"; } : radio_button { key = \"pr_Ambos\"; label = \"Ambos\"; } : radio_button { key = \"pr_Nenhum\"; label = \"Nenhum\"; } } }" f)
  (write-line "  : row { : text { label = \"Adicionar Base?\"; width = 22; } : toggle { key = \"base_I\"; label = \"\"; } }" f)
  (write-line "  : spacer { height = 1; } : text { label = \"--- REMOVENDO ---\"; width = 50; }" f)
  (write-line "  : row { : text { label = \"Trafo?\"; width = 22; } : toggle { key = \"trafo_R\"; label = \"\"; } }" f)
  (write-line "  : row { : text { label = \"  Potencia (kVA):\"; width = 22; } : popup_list { key = \"pot_R\"; width = 14; } }" f)
  (write-line "  : row { : text { label = \"Chave?\"; width = 22; } : toggle { key = \"chave_R\"; label = \"\"; } }" f)
  (write-line "  : row { : text { label = \"  Quantidade:\"; width = 22; } : radio_row { : radio_button { key = \"qty_R_1\"; label = \"1\"; } : radio_button { key = \"qty_R_3\"; label = \"3\"; } } }" f)
  (write-line "  : row { : text { label = \"  Elo:\"; width = 22; } : popup_list { key = \"elo_R\"; width = 14; } }" f)
  (write-line "  : row { : text { label = \"  Esforco:\"; width = 22; } : radio_row { : radio_button { key = \"esf_R_M\"; label = \"Maior\"; } : radio_button { key = \"esf_R_m\"; label = \"Menor\"; } } }" f)
  (write-line "  : spacer { height = 1; }" f)
  (write-line "  : row { : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; } : button { key = \"cancel\"; label = \"Cancelar\"; is_cancel = true; width = 12; } }" f)
  (write-line "}" f)
  (close f)
  ;;; =========================================================================

  ;;; LOOP PRINCIPAL
  (setq main_loop T)
  (while main_loop

    (setq dcl_id (load_dialog dcl_file))
    (if (< dcl_id 0) (progn (alert "Erro ao carregar DCL Temporário.") (exit)))
    (if (not (new_dialog "poste_dlg" dcl_id))
      (progn (alert "Erro ao abrir poste_dlg.") (unload_dialog dcl_id) (exit)))

    (update-desc-lists)
    (update-preset-lists)

    (start_list "pot_I") (foreach v pot_list (add_list v)) (end_list)
    (start_list "pot_R") (foreach v pot_list (add_list v)) (end_list)
    (start_list "elo_I") (foreach v elo_list (add_list v)) (end_list)
    (start_list "elo_R") (foreach v elo_list (add_list v)) (end_list)

    (set_tile "preset_name" v_selected_preset)
    (set_tile "desc_I" v_desc_I)
    (set_tile "desc_R" v_desc_R)
    (set_tile "coord_X" v_coord_X)
    (set_tile "coord_Y" v_coord_Y)
    
    (set_tile "tipo_I" (if (= v_tipo "I") "1" "0"))
    (set_tile "tipo_R" (if (= v_tipo "R") "1" "0"))
    (set_tile "tipo_S" (if (= v_tipo "S") "1" "0"))

    (set_tile "trafo_I" (itoa v_trafo_I))
    (set_tile "pot_I"   (itoa v_pot_I))
    (set_tile "chave_I" (itoa v_chave_I))
    (set_tile "elo_I"   (itoa v_elo_I))
    (set_tile "terra_I" (itoa v_terra_I))
    (set_tile "base_I"  (itoa v_base_I))

    (set_tile "trafo_R" (itoa v_trafo_R))
    (set_tile "pot_R"   (itoa v_pot_R))
    (set_tile "chave_R" (itoa v_chave_R))
    (set_tile "elo_R"   (itoa v_elo_R))

    (set_tile "qty_I_1" (if (= v_qty_I "1") "1" "0"))
    (set_tile "qty_I_3" (if (= v_qty_I "3") "1" "0"))
    (set_tile "qty_R_1" (if (= v_qty_R "1") "1" "0"))
    (set_tile "qty_R_3" (if (= v_qty_R "3") "1" "0"))

    (set_tile "pr_Nenhum" (if (= v_pr_I "Nenhum") "1" "0"))
    (set_tile "pr_PRMT"   (if (= v_pr_I "PRMT")   "1" "0"))
    (set_tile "pr_PRBT"   (if (= v_pr_I "PRBT")   "1" "0"))
    (set_tile "pr_Ambos"  (if (= v_pr_I "Ambos")  "1" "0"))

    (set_tile "esf_I_M" (if (= v_esf_I "M") "1" "0"))
    (set_tile "esf_I_m" (if (= v_esf_I "m") "1" "0"))
    (set_tile "esf_R_M" (if (= v_esf_R "M") "1" "0"))
    (set_tile "esf_R_m" (if (= v_esf_R "m") "1" "0"))

    ;;; -----------------------------------------------------------------------
    ;;; ESTADOS INICIAIS DE HABILITAR/DESABILITAR
    ;;; -----------------------------------------------------------------------
    (cond
      ((= v_tipo "I")
        (mode_tile "desc_R"    1) (mode_tile "list_desc_R" 1) (mode_tile "btn_save_R" 1) (mode_tile "btn_rem_R" 1)
        (mode_tile "trafo_R"   1) (mode_tile "pot_R"       1)
        (mode_tile "chave_R"   1) (mode_tile "qty_R_1"     1) (mode_tile "qty_R_3" 1) (mode_tile "elo_R" 1)
        (mode_tile "esf_R_M"   1) (mode_tile "esf_R_m"     1)
        (mode_tile "trafo_I"   0) (mode_tile "pot_I"       (if (= v_trafo_I 1) 0 1))
        (mode_tile "chave_I"   0)
        (mode_tile "qty_I_1"   (if (= v_chave_I 1) 0 1)) (mode_tile "qty_I_3" (if (= v_chave_I 1) 0 1))
        (mode_tile "elo_I"     (if (= v_chave_I 1) 0 1))
        (mode_tile "esf_I_M"   (if (= v_chave_I 1) 0 1)) (mode_tile "esf_I_m" (if (= v_chave_I 1) 0 1))
        (mode_tile "terra_I"   0) (mode_tile "base_I" 0)
        (mode_tile "pr_PRMT"   0) (mode_tile "pr_PRBT" 0) (mode_tile "pr_Ambos" 0) (mode_tile "pr_Nenhum" 0))

      ((= v_tipo "R")
        (mode_tile "trafo_I"   1) (mode_tile "pot_I"   1)
        (mode_tile "chave_I"   1) (mode_tile "qty_I_1" 1) (mode_tile "qty_I_3" 1) (mode_tile "elo_I" 1)
        (mode_tile "esf_I_M"   1) (mode_tile "esf_I_m" 1)
        (mode_tile "terra_I"   1) (mode_tile "base_I"  1)
        (mode_tile "pr_PRMT"   1) (mode_tile "pr_PRBT" 1) (mode_tile "pr_Ambos" 1) (mode_tile "pr_Nenhum" 1)
        (mode_tile "desc_R"    1) (mode_tile "list_desc_R" 1) (mode_tile "btn_save_R" 1) (mode_tile "btn_rem_R" 1)
        (mode_tile "trafo_R"   0) (mode_tile "pot_R"       (if (= v_trafo_R 1) 0 1))
        (mode_tile "chave_R"   0)
        (mode_tile "qty_R_1"   (if (= v_chave_R 1) 0 1)) (mode_tile "qty_R_3" (if (= v_chave_R 1) 0 1))
        (mode_tile "elo_R"     (if (= v_chave_R 1) 0 1))
        (mode_tile "esf_R_M"   (if (= v_chave_R 1) 0 1)) (mode_tile "esf_R_m" (if (= v_chave_R 1) 0 1)))

      ((= v_tipo "S")
        (mode_tile "desc_R"    0) (mode_tile "list_desc_R" 0) (mode_tile "btn_save_R" 0) (mode_tile "btn_rem_R" 0)
        (mode_tile "trafo_I"   0) (mode_tile "pot_I"       (if (= v_trafo_I 1) 0 1))
        (mode_tile "chave_I"   0)
        (mode_tile "qty_I_1"   (if (= v_chave_I 1) 0 1)) (mode_tile "qty_I_3" (if (= v_chave_I 1) 0 1))
        (mode_tile "elo_I"     (if (= v_chave_I 1) 0 1))
        (mode_tile "esf_I_M"   (if (= v_chave_I 1) 0 1)) (mode_tile "esf_I_m" (if (= v_chave_I 1) 0 1))
        (mode_tile "terra_I"   0) (mode_tile "base_I" 0)
        (mode_tile "pr_PRMT"   0) (mode_tile "pr_PRBT" 0) (mode_tile "pr_Ambos" 0) (mode_tile "pr_Nenhum" 0)
        (mode_tile "trafo_R"   0) (mode_tile "pot_R"       (if (= v_trafo_R 1) 0 1))
        (mode_tile "chave_R"   0)
        (mode_tile "qty_R_1"   (if (= v_chave_R 1) 0 1)) (mode_tile "qty_R_3" (if (= v_chave_R 1) 0 1))
        (mode_tile "elo_R"     (if (= v_chave_R 1) 0 1))
        (mode_tile "esf_R_M"   (if (= v_chave_R 1) 0 1)) (mode_tile "esf_R_m" (if (= v_chave_R 1) 0 1)))
    )

    ;;; -----------------------------------------------------------------------
    ;;; CALLBACKS
    ;;; -----------------------------------------------------------------------

    ;; PERFIS
    (action_tile "list_presets" "(if (> (atoi $value) 0) (progn (setq v_selected_preset (nth (atoi $value) preset_list)) (apply-preset-to-vars v_selected_preset) (done_dialog 2)))")
    (action_tile "btn_save_preset" "(if (save-preset (get_tile \"preset_name\")) (update-preset-lists))")
    (action_tile "btn_rem_preset"  "(if (remove-preset (get_tile \"preset_name\")) (update-preset-lists))")

    ;; OPERACAO
    (action_tile "tipo_I"
      "(set_tile \"tipo_I\" \"1\") (set_tile \"tipo_R\" \"0\") (set_tile \"tipo_S\" \"0\")
       (mode_tile \"desc_R\" 1) (mode_tile \"list_desc_R\" 1) (mode_tile \"btn_save_R\" 1) (mode_tile \"btn_rem_R\" 1)
       (mode_tile \"trafo_R\" 1) (mode_tile \"pot_R\" 1)
       (mode_tile \"chave_R\" 1) (mode_tile \"qty_R_1\" 1) (mode_tile \"qty_R_3\" 1) (mode_tile \"elo_R\" 1) (mode_tile \"esf_R_M\" 1) (mode_tile \"esf_R_m\" 1)
       (mode_tile \"trafo_I\" 0) (mode_tile \"chave_I\" 0)
       (mode_tile \"terra_I\" 0) (mode_tile \"base_I\" 0)
       (mode_tile \"pr_PRMT\" 0) (mode_tile \"pr_PRBT\" 0) (mode_tile \"pr_Ambos\" 0) (mode_tile \"pr_Nenhum\" 0)")

    (action_tile "tipo_R"
      "(set_tile \"tipo_I\" \"0\") (set_tile \"tipo_R\" \"1\") (set_tile \"tipo_S\" \"0\")
       (mode_tile \"trafo_I\" 1) (mode_tile \"pot_I\" 1)
       (mode_tile \"chave_I\" 1) (mode_tile \"qty_I_1\" 1) (mode_tile \"qty_I_3\" 1) (mode_tile \"elo_I\" 1) (mode_tile \"esf_I_M\" 1) (mode_tile \"esf_I_m\" 1)
       (mode_tile \"terra_I\" 1) (mode_tile \"base_I\" 1)
       (mode_tile \"pr_PRMT\" 1) (mode_tile \"pr_PRBT\" 1) (mode_tile \"pr_Ambos\" 1) (mode_tile \"pr_Nenhum\" 1)
       (mode_tile \"desc_R\" 1) (mode_tile \"list_desc_R\" 1) (mode_tile \"btn_save_R\" 1) (mode_tile \"btn_rem_R\" 1)
       (mode_tile \"trafo_R\" 0) (mode_tile \"pot_R\" 1)
       (mode_tile \"chave_R\" 0) (mode_tile \"qty_R_1\" 1) (mode_tile \"qty_R_3\" 1) (mode_tile \"elo_R\" 1)")

    (action_tile "tipo_S"
      "(set_tile \"tipo_I\" \"0\") (set_tile \"tipo_R\" \"0\") (set_tile \"tipo_S\" \"1\")
       (mode_tile \"desc_R\" 0) (mode_tile \"list_desc_R\" 0) (mode_tile \"btn_save_R\" 0) (mode_tile \"btn_rem_R\" 0)
       (mode_tile \"trafo_I\" 0) (mode_tile \"chave_I\" 0)
       (mode_tile \"terra_I\" 0) (mode_tile \"base_I\" 0)
       (mode_tile \"pr_PRMT\" 0) (mode_tile \"pr_PRBT\" 0) (mode_tile \"pr_Ambos\" 0) (mode_tile \"pr_Nenhum\" 0)
       (mode_tile \"trafo_R\" 0) (mode_tile \"pot_R\" 1)
       (mode_tile \"chave_R\" 0) (mode_tile \"qty_R_1\" 1) (mode_tile \"qty_R_3\" 1) (mode_tile \"elo_R\" 1)")

    ;; PR, QUANTIDADES E ESFORCOS
    (action_tile "pr_PRMT"   "(set_tile \"pr_PRMT\" \"1\") (set_tile \"pr_PRBT\" \"0\") (set_tile \"pr_Ambos\" \"0\") (set_tile \"pr_Nenhum\" \"0\")")
    (action_tile "pr_PRBT"   "(set_tile \"pr_PRMT\" \"0\") (set_tile \"pr_PRBT\" \"1\") (set_tile \"pr_Ambos\" \"0\") (set_tile \"pr_Nenhum\" \"0\")")
    (action_tile "pr_Ambos"  "(set_tile \"pr_PRMT\" \"0\") (set_tile \"pr_PRBT\" \"0\") (set_tile \"pr_Ambos\" \"1\") (set_tile \"pr_Nenhum\" \"0\")")
    (action_tile "pr_Nenhum" "(set_tile \"pr_PRMT\" \"0\") (set_tile \"pr_PRBT\" \"0\") (set_tile \"pr_Ambos\" \"0\") (set_tile \"pr_Nenhum\" \"1\")")
    (action_tile "qty_I_1"   "(set_tile \"qty_I_1\" \"1\") (set_tile \"qty_I_3\" \"0\")")
    (action_tile "qty_I_3"   "(set_tile \"qty_I_1\" \"0\") (set_tile \"qty_I_3\" \"1\")")
    (action_tile "qty_R_1"   "(set_tile \"qty_R_1\" \"1\") (set_tile \"qty_R_3\" \"0\")")
    (action_tile "qty_R_3"   "(set_tile \"qty_R_1\" \"0\") (set_tile \"qty_R_3\" \"1\")")
    
    (action_tile "esf_I_M"   "(set_tile \"esf_I_M\" \"1\") (set_tile \"esf_I_m\" \"0\")")
    (action_tile "esf_I_m"   "(set_tile \"esf_I_M\" \"0\") (set_tile \"esf_I_m\" \"1\")")
    (action_tile "esf_R_M"   "(set_tile \"esf_R_M\" \"1\") (set_tile \"esf_R_m\" \"0\")")
    (action_tile "esf_R_m"   "(set_tile \"esf_R_M\" \"0\") (set_tile \"esf_R_m\" \"1\")")

    ;; TRAFO / CHAVE
    (action_tile "trafo_I" "(if (= $value \"1\") (mode_tile \"pot_I\" 0) (mode_tile \"pot_I\" 1))")
    (action_tile "chave_I" "(if (= $value \"1\") (progn (mode_tile \"qty_I_1\" 0) (mode_tile \"qty_I_3\" 0) (mode_tile \"elo_I\" 0) (mode_tile \"esf_I_M\" 0) (mode_tile \"esf_I_m\" 0)) (progn (mode_tile \"qty_I_1\" 1) (mode_tile \"qty_I_3\" 1) (mode_tile \"elo_I\" 1) (mode_tile \"esf_I_M\" 1) (mode_tile \"esf_I_m\" 1)))")
    (action_tile "trafo_R" "(if (= $value \"1\") (mode_tile \"pot_R\" 0) (mode_tile \"pot_R\" 1))")
    (action_tile "chave_R" "(if (= $value \"1\") (progn (mode_tile \"qty_R_1\" 0) (mode_tile \"qty_R_3\" 0) (mode_tile \"elo_R\" 0) (mode_tile \"esf_R_M\" 0) (mode_tile \"esf_R_m\" 0)) (progn (mode_tile \"qty_R_1\" 1) (mode_tile \"qty_R_3\" 1) (mode_tile \"elo_R\" 1) (mode_tile \"esf_R_M\" 1) (mode_tile \"esf_R_m\" 1)))")

    ;; LISTAS E BOTOES DE DESCRICAO
    (action_tile "list_desc_I" "(if (> (atoi $value) 0) (set_tile \"desc_I\" (nth (atoi $value) desc_list)))")
    (action_tile "list_desc_R" "(if (> (atoi $value) 0) (set_tile \"desc_R\" (nth (atoi $value) desc_list)))")
    (action_tile "btn_save_I"  "(if (save-descricao (get_tile \"desc_I\")) (update-desc-lists))")
    (action_tile "btn_rem_I"   "(if (remove-descricao (get_tile \"desc_I\")) (update-desc-lists))")
    (action_tile "btn_save_R"  "(if (save-descricao (get_tile \"desc_R\")) (update-desc-lists))")
    (action_tile "btn_rem_R"   "(if (remove-descricao (get_tile \"desc_R\")) (update-desc-lists))")

    ;; OK - coleta valores
    (action_tile "accept"
      "(setq v_desc_I   (get_tile \"desc_I\")
             v_desc_R   (get_tile \"desc_R\")
             v_coord_X  (get_tile \"coord_X\")
             v_coord_Y  (get_tile \"coord_Y\")
             v_tipo     (cond ((= (get_tile \"tipo_S\") \"1\") \"S\") ((= (get_tile \"tipo_R\") \"1\") \"R\") (T \"I\"))
             v_trafo_I  (atoi (get_tile \"trafo_I\")) v_pot_I (atoi (get_tile \"pot_I\"))
             v_chave_I  (atoi (get_tile \"chave_I\")) v_elo_I (atoi (get_tile \"elo_I\"))
             v_terra_I  (atoi (get_tile \"terra_I\")) v_base_I (atoi (get_tile \"base_I\"))
             v_trafo_R  (atoi (get_tile \"trafo_R\")) v_pot_R (atoi (get_tile \"pot_R\"))
             v_chave_R  (atoi (get_tile \"chave_R\")) v_elo_R (atoi (get_tile \"elo_R\"))
             v_qty_I    (if (= (get_tile \"qty_I_3\") \"1\") \"3\" \"1\")
             v_qty_R    (if (= (get_tile \"qty_R_3\") \"1\") \"3\" \"1\")
             v_esf_I    (if (= (get_tile \"esf_I_m\") \"1\") \"m\" \"M\")
             v_esf_R    (if (= (get_tile \"esf_R_m\") \"1\") \"m\" \"M\")
             v_pr_I     (cond ((= (get_tile \"pr_PRMT\")  \"1\") \"PRMT\")
                              ((= (get_tile \"pr_PRBT\")  \"1\") \"PRBT\")
                              ((= (get_tile \"pr_Ambos\") \"1\") \"Ambos\")
                              (T \"Nenhum\")))
       (done_dialog 1) (princ)")
       
    (action_tile "cancel" "(done_dialog 0) (princ)")

    (setq dlg_result (start_dialog))
    (unload_dialog dcl_id)

    ;;; SELECAO DE RESULTADO DO DIALOGO
    (cond 
      ((= dlg_result 2)
        ;; Dialog recarregou devido a aplicacao do Preset. Retorna ao inicio do While.
        (princ)
      )
      
      ((= dlg_result 1)
        ;;; OK PRESSIONADO, INICIA INSERCAO NO DESENHO
        (setq main_loop nil)
        
        (progn
          ;;; PROCESSAR COORDENADA OPCIONAL
          (setq use_coord nil)
          (if (and (/= (vl-string-trim " " v_coord_X) "")
                   (/= (vl-string-trim " " v_coord_Y) ""))
            (progn
              (setq coord_pt (list (atof v_coord_X) (atof v_coord_Y) 0.0))
              (setq use_coord T)))

          ;;; NORMALIZAR DESCRICOES: trim + maiusculo antes de qualquer wcmatch
          (setq desc_I (vl-string-trim " " (strcase v_desc_I)) tipo v_tipo)
          (if (= tipo "R")
            (setq desc_R desc_I desc_I "")
            (setq desc_R (vl-string-trim " " (strcase v_desc_R))))

          ;;; VERIFICACAO: desenha bloco do poste somente se desc contiver "DT" ou "CV"
          (setq draw_poste_I (and (/= desc_I "") (wcmatch desc_I "*DT*,*CV*")))
          (setq draw_poste_R (and (/= desc_R "") (wcmatch desc_R "*DT*,*CV*")))

          ;;; SELECAO DO BLOCO: CV usa símbolo diferente de DT
          (setq bloco_poste_I
            (if (and (/= desc_I "") (wcmatch desc_I "*CV*")) "POSTE_CV_I" "POSTE_I"))
          (setq bloco_poste_R
            (if (and (/= desc_R "") (wcmatch desc_R "*CV*")) "POSTE_CV_R" "POSTE_R"))

          (setq has_trafo_I (= v_trafo_I 1) has_chave_I (= v_chave_I 1)
                has_trafo_R (= v_trafo_R 1) has_chave_R (= v_chave_R 1)
                has_prbt_I  (or (= v_pr_I "PRBT") (= v_pr_I "Ambos")))

          (setq pot_I_str (nth v_pot_I pot_list) pot_R_str (nth v_pot_R pot_list)
                elo_I_str (nth v_elo_I elo_list) elo_R_str (nth v_elo_R elo_list))

          (setq trafo_txt_I nil chave_txt_I nil trafo_txt_R nil chave_txt_R nil)
          (if has_trafo_I (setq trafo_txt_I (if (= pot_I_str "25") "TR - 1 - 25kVA" (strcat "TR - 3 - " pot_I_str "kVA"))))
          (if has_chave_I (setq chave_txt_I (strcat v_qty_I " - 100A - " elo_I_str)))
          (if has_trafo_R (setq trafo_txt_R (strcat "TR - 3 - " pot_R_str "kVA")))
          (if has_chave_R (setq chave_txt_R (strcat v_qty_R " - 100A - " elo_R_str)))

          ;;; NOS E BLOCOS EXTRAS
          (setq nodes_I '() extra_blocks_I '() extra_blocks_R '())
          (if (and (/= desc_I "")
                   (wcmatch desc_I "*-N[1234]*,*-B[1234]*,*-CE*,*-TA*,*-TB*,*-U*,*-R[1234]*"))
            (setq nodes_I (append nodes_I '("NO_MT"))))
          
          ;; ====== REGRA REFINADA PARA NO_BT AQUI ======
          (if (and (/= desc_I "")
                   (wcmatch desc_I "*-S[12345]*,*-SI[134]*,*-BI[123456789]*,*-RA[12]*"))
            (setq nodes_I (append nodes_I '("NO_BT"))))
          ;; ============================================

          (setq only_bt    (and (member "NO_BT" nodes_I) (not (member "NO_MT" nodes_I))))
          (setq draw_nodes_I (if only_bt '("NO_MT") nodes_I))

          (if (= v_terra_I 1)
            (setq extra_blocks_I
              (append extra_blocks_I
                (list (if (wcmatch desc_I "*CV*") "TERRA3_I_CV" "TERRA3_I")))))
          
          ;; CONDICIONAL PARA SEPARAR O TRAFO DA CHAVE EM CASO DE MENOR ESFORCO
          (if (not only_bt)
            (if (and has_trafo_I has_chave_I)
              (if (= v_esf_I "m")
                (setq extra_blocks_I (append extra_blocks_I '("TRAFO_I" "CHAVE_I")))
                (setq extra_blocks_I (append extra_blocks_I '("TRAFO_CH_I")))
              )
              (cond
                (has_trafo_I (setq extra_blocks_I (append extra_blocks_I '("TRAFO_I"))))
                (has_chave_I (setq extra_blocks_I (append extra_blocks_I '("CHAVE_I"))))
              )
            )
          )

          (cond
            ((= v_pr_I "PRMT")  (setq extra_blocks_I (append extra_blocks_I '("PRMT_I"))))
            ((= v_pr_I "PRBT")  (setq extra_blocks_I (append extra_blocks_I '("PRBT_I"))))
            ((= v_pr_I "Ambos") (setq extra_blocks_I (append extra_blocks_I '("PRMT_I" "PRBT_I")))))
          
          (if (= v_base_I 1)
            (setq extra_blocks_I
              (append extra_blocks_I
                (list (if (wcmatch desc_I "*CV*") "BASE_CV_MP" "BASE_MP")))))

          (if (and has_trafo_R has_chave_R)
            (if (= v_esf_R "m")
              (setq extra_blocks_R (append extra_blocks_R '("TRAFO_R" "CHAVE_R")))
              (setq extra_blocks_R (append extra_blocks_R '("TRAFO_CH_R")))
            )
            (cond
              (has_trafo_R (setq extra_blocks_R (append extra_blocks_R '("TRAFO_R"))))
              (has_chave_R (setq extra_blocks_R (append extra_blocks_R '("CHAVE_R"))))
            )
          )

          (setq base_ang    (if (or has_trafo_I has_chave_I has_trafo_R has_chave_R) (/ pi 2.0) (* pi 1.5)))
          (setq offset_dist (if only_bt 2.2033 0.0))

          ;;; PRE-PROCESSAMENTO PILHA blocks_data
          (setq blocks_data '())
          (if (or (= tipo "I") (= tipo "S"))
            (progn
              (setq texts_list_I (if has_prbt_I (list "INST. PRBT") nil))
              (setq texts_list_I (append texts_list_I (list desc_I)))
              (if has_trafo_I (setq texts_list_I (append texts_list_I (list trafo_txt_I))))
              (if has_chave_I (setq texts_list_I (append texts_list_I (list chave_txt_I))))
              (foreach t_str texts_list_I
                (if (and t_str (/= t_str ""))
                  (setq blocks_data (append blocks_data (list (list t_str "I"))))))))
              
          (if (or (= tipo "R") (= tipo "S"))
            (progn
              (setq texts_list_R (list desc_R))
              (if has_trafo_R (setq texts_list_R (append texts_list_R (list trafo_txt_R))))
              (if has_chave_R (setq texts_list_R (append texts_list_R (list chave_txt_R))))
              (foreach t_str texts_list_R
                (if (and t_str (/= t_str ""))
                  (setq blocks_data (append blocks_data (list (list t_str "R"))))))))

          ;;; -----------------------------------------------------------------------
          ;;; FUNCAO AUXILIAR LOCAL: insere blocos em um ponto de referencia
          ;;; -----------------------------------------------------------------------
          (defun insere-blocos (p1_ref ang_ref / ang_poste_I ang_poste_R blk_ang)
            
            ;; O POSTE gira -90 caso o esforco seja menor E uma chave exista. A Chave continuara usando ang_ref.
            (setq ang_poste_I (if (and has_chave_I (= v_esf_I "m")) (- ang_ref (/ pi 2.0)) ang_ref))
            (setq ang_poste_R (if (and has_chave_R (= v_esf_R "m")) (- ang_ref (/ pi 2.0)) ang_ref))

            ;; O distanciamento (offset) eh mantido com base no ang_ref para que o bloco ainda siga a linha da rede fisicamente
            (setq final_p1_I (polar p1_ref (- ang_ref base_ang) offset_dist))
            (setq final_p1_R (if (= tipo "S") (polar final_p1_I ang_ref 3.0) final_p1_I))
            (setq ref_pt     (if (= tipo "R") final_p1_R final_p1_I))

            (if (or (= tipo "R") (= tipo "S"))
              (progn
                (if draw_poste_R
                  (entmake (list '(0 . "INSERT") (cons 2 bloco_poste_R)
                                 (cons 10 final_p1_R)
                                 (cons 50 (if (= tipo "S") (+ ang_poste_R (/ pi 2.0)) ang_poste_R)))))
                (foreach b extra_blocks_R
                  (setq blk_ang (if (wcmatch b "*CHAVE*") ang_ref ang_poste_R))
                  (if (tblsearch "BLOCK" b)
                    (entmake (list '(0 . "INSERT") (cons 2 b)
                                   (cons 10 final_p1_R)
                                   (cons 50 (if (= tipo "S") (+ blk_ang (/ pi 2.0)) blk_ang))))))))

            (if (or (= tipo "I") (= tipo "S"))
              (progn
                (if draw_poste_I
                  (entmake (list '(0 . "INSERT") (cons 2 bloco_poste_I)
                                 (cons 10 final_p1_I) (cons 50 ang_poste_I))))
                (foreach b extra_blocks_I
                  (setq blk_ang (if (wcmatch b "*CHAVE*") ang_ref ang_poste_I))
                  (if (tblsearch "BLOCK" b)
                    (entmake (list '(0 . "INSERT") (cons 2 b)
                                   (cons 10 final_p1_I) (cons 50 blk_ang)))))
                (foreach b draw_nodes_I
                  (if (tblsearch "BLOCK" b)
                    (entmake (list '(0 . "INSERT") (cons 2 b)
                                   (cons 10 p1_ref) (cons 50 ang_poste_I)))))))
          )

          ;;; -----------------------------------------------------------------------
          ;;; FUNCAO AUXILIAR LOCAL: desenha anotacoes (MTEXT + bordas/riscos)
          ;;; -----------------------------------------------------------------------
          (defun desenha-anotacoes ()
            (setq base_X  (+ (car  ref_pt) last_vec_X)
                  base_Y  (+ (cadr ref_pt) last_vec_Y)
                  cur_Y   base_Y
                  justify (if (= lado "R") 4 6))
            (foreach b_data blocks_data
              (setq t_str (nth 0 b_data) style (nth 1 b_data))
              (entmake (list '(0 . "MTEXT") '(100 . "AcDbEntity") '(100 . "AcDbMText")
                             (cons 10 (list base_X cur_Y (caddr ref_pt)))
                             (cons 40 txtH) '(41 . 0.0) (cons 71 justify)
                             (cons 1 t_str) (cons 62 (if (= style "I") 1 8))))
              (setq ent_txt (entlast) vla_obj (vlax-ename->vla-object ent_txt))
              (vla-getboundingbox vla_obj 'minpt 'maxpt)
              (setq min_l (vlax-safearray->list minpt) max_l (vlax-safearray->list maxpt))
              (if (= style "I")
                (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
                               '(90 . 4) '(70 . 1) (cons 62 1)
                               (cons 10 (list (- (car min_l) pad_h) (- (cadr min_l) pad_v)))
                               (cons 10 (list (+ (car max_l) pad_h) (- (cadr min_l) pad_v)))
                               (cons 10 (list (+ (car max_l) pad_h) (+ (cadr max_l) pad_v)))
                               (cons 10 (list (- (car min_l) pad_h) (+ (cadr max_l) pad_v))))))
              (if (= style "R")
                (entmake (list '(0 . "LINE")
                               (cons 10 (list (- (car min_l) pad_risco) (/ (+ (cadr min_l) (cadr max_l)) 2.0)))
                               (cons 11 (list (+ (car max_l) pad_risco) (/ (+ (cadr min_l) (cadr max_l)) 2.0)))
                               (cons 62 8))))
              (setq cur_Y (- (cadr min_l) pad_v box_gap pad_v (/ txtH 2.0))))
          )

          ;;; -----------------------------------------------------------------------
          ;;; LOOP DE INSERCAO
          ;;; -----------------------------------------------------------------------
          (setq first_run T last_ang base_ang last_vec_X 3.0 last_vec_Y 0.0 insertion_loop T lado "R")
          
          (while insertion_loop
            (if use_coord

              ;; --- MODO COORDENADA ---
              (progn
                (if first_run
                  (progn
                    (setq last_ang base_ang)
                    (insere-blocos coord_pt last_ang)
                    (setq last_vec_X 3.0 last_vec_Y 0.0 lado "R" first_run nil))
                  (progn
                    ;; Ja inseriu uma vez — desenha anotacoes e encerra
                    (desenha-anotacoes)
                    (setq insertion_loop nil main_loop nil)))
              )

              ;; --- MODO CLIQUE ---
              (progn
                (initget "Ajustar Reconfigurar")
                (setq pt_input (getpoint
                  (if first_run
                    "\n1o Clique: Centro (rede) ou [Reconfigurar]: "
                    "\nClique (Centro) ou [Ajustar/Reconfigurar] <Sair>: ")))
                
                (cond
                  ;; CORRIGIDO: Retorna ao DCL reativando o main_loop
                  ((= pt_input "Reconfigurar")
                    (setq insertion_loop nil main_loop T))
                  
                  ((not pt_input)
                    (setq insertion_loop nil main_loop nil)) ;; Enter/Espaco/Dir = sair
                  
                  ((= pt_input "Ajustar")
                    (setq first_run T))
                  
                  (T ;; Clique valido
                    (setq p1 pt_input)
                    (if first_run
                      (progn
                        ;; 1o clique: pede direcao
                        (setq p2 (getangle p1
                          (strcat "\n2o Clique: Direcao (ENTER p/ "
                                  (if (or has_trafo_I has_chave_I) "90" "270") "): ")))
                        (setq last_ang (if p2 (+ p2 base_ang) base_ang))
                        (insere-blocos p1 last_ang)
                        ;; 3o clique: ponto base da anotacao
                        (setq p3 (getpoint ref_pt "\n3o Clique: Ponto Base da Anotacao: "))
                        (if p3
                          (setq last_vec_X (- (car p3)  (car  ref_pt))
                                last_vec_Y (- (cadr p3) (cadr ref_pt))
                                lado       (if (>= (car p3) (car ref_pt)) "R" "L"))
                          (setq last_vec_X 3.0 last_vec_Y 0.0 lado "R"))
                        (setq first_run nil))
                      
                      (progn
                        ;; Cliques subsequentes: reutiliza angulo e vetor do 1o clique
                        (insere-blocos p1 last_ang)))

                    ;; Anotacoes apos cada clique valido
                    (desenha-anotacoes))
                )
              )
            )
          )
        )
      )
      
      (T
        ;;; SE CANCELOU NO DCL, ENCERRA
        (setq main_loop nil)
      )
    )
  )
  
  ;;; LIMPEZA DO ARQUIVO DCL TEMPORARIO
  (if (findfile dcl_file) (vl-file-delete dcl_file))

  (princ)
)