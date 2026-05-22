;;; ============================================================
;;; CARIMBO_PREENCHER.LSP  (v12.0 - Correcoes e Melhorias)
;;; NanoCAD 5 / AutoCAD - AutoLISP classico
;;; ============================================================
;;; CHANGELOG v12.0:
;;;   [FIX] get-date-today: usa rtos em vez de itoa(fix()) para evitar falha com float
;;;   [FIX] normaliza-busca: removidas 3 substituicoes redundantes (I->I, A->A, O->O)
;;;   [FIX] extrai-campo ORCAMENTO: busca "ORCAMENTO" normalizado diretamente
;;;   [REFACTOR] limpa-texto-puro e limpa-texto-objetivo unificadas em limpa-texto
;;;   [NOTE] atualiza-dxf-texto: comentario de aviso sobre MText longo adicionado
;;;   [NEW] Campo REFERENCIAS auto-preenchido com "SEM REF" se vier vazio
;;; ============================================================

;;; ============================================================
;;; FUNCOES DE STRING 100% SEGURAS (Anti-Travamento)
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

;;; ============================================================
;;; CRIACAO DO DCL TEMPORARIO
;;; ============================================================
(defun cria-dcl-temp (/ dcl-file f dcl-lines)
  (setq dcl-file (vl-filename-mktemp "carimbo.dcl"))
  (setq f (open dcl-file "w"))
  
  (setq dcl-lines
    (list
      "carimbo_dlg : dialog {"
      "  label = \"Preencher Carimbo - Engeselt\";"
      "  width = 62;"
      "  : boxed_column {"
      "    label = \"Colar dados da OS\";"
      "    : text {"
      "      label = \"Cole o texto da OS abaixo (uma linha) e clique em Aplicar:\";"
      "    }"
      "    : text {"
      "      label = \"Ex: OS: 969414610 | DM: 0000 | ALIM: 00000 | SOLICITANTE: FULANO | ENDERECO: RUA X | TEC: JOSE\";"
      "    }"
      "    : row {"
      "      : edit_box {"
      "        key         = \"TEXTO_OS\";"
      "        width       = 50;"
      "        edit_limit  = 2000;"
      "        fixed_width = true;"
      "      }"
      "      : button {"
      "        key   = \"btn_colar_os\";"
      "        label = \"  Aplicar OS  \";"
      "        width = 14;"
      "      }"
      "    }"
      "  }"
      "  spacer;"
      "  : row {"
      "    : boxed_column {"
      "      label = \"Data\";"
      "      width = 24;"
      "      : row {"
      "        : edit_box { key = \"DATA\"; width = 12; }"
      "        : button { key = \"btn_hoje\"; label = \"Hoje\"; width = 6; }"
      "      }"
      "    }"
      "    : boxed_column {"
      "      label = \"Escala\";"
      "      width = 20;"
      "      : edit_box { key = \"ESCALA\"; width = 16; }"
      "    }"
      "    : boxed_column {"
      "      label = \"Grau de Risco\";"
      "      width = 20;"
      "      : popup_list { key = \"GRAU_RISCO\"; width = 16; }"
      "    }"
      "  }"
      "  : row {"
      "    : boxed_column {"
      "      label = \"Regional\";"
      "      width = 30;"
      "      : popup_list { key = \"REGIONAL\"; width = 26; }"
      "    }"
      "    : boxed_column {"
      "      label = \"Alimentador\";"
      "      width = 30;"
      "      : edit_box { key = \"ALIMENTADOR\"; width = 26; }"
      "    }"
      "  }"
      "  : boxed_column {"
      "    label = \"Servico\";"
      "    : edit_box { key = \"SERVICO\"; width = 58; }"
      "  }"
      "  : boxed_column {"
      "    label = \"Objetivo\";"
      "    : edit_box { key = \"OBJETIVO\"; width = 58; }"
      "  }"
      "  : row {"
      "    : boxed_column {"
      "      label = \"OS / DM\";"
      "      width = 24;"
      "      : edit_box { key = \"OS_DM\"; width = 20; }"
      "    }"
      "    : boxed_column {"
      "      label = \"Orcamento\";"
      "      width = 18;"
      "      : edit_box { key = \"ORCAMENTO\"; width = 14; }"
      "    }"
      "    : boxed_column {"
      "      label = \"Componente\";"
      "      width = 18;"
      "      : edit_box { key = \"COMPONENTE\"; width = 14; }"
      "    }"
      "  }"
      "  : row {"
      "    : boxed_column {"
      "      label = \"Levantamento\";"
      "      width = 30;"
      "      : edit_box { key = \"LEVANTAMENTO\"; width = 26; }"
      "    }"
      "    : boxed_column {"
      "      label = \"Desenho\";"
      "      width = 30;"
      "      : edit_box { key = \"DESENHO\"; width = 26; }"
      "    }"
      "  }"
      "  : boxed_column {"
      "    label = \"Obra N.\";"
      "    : edit_box { key = \"OBRA\"; width = 58; }"
      "  }"
      "  : boxed_column {"
      "    label = \"Informacoes Compostas\";"
      "    : row {"
      "      : boxed_column {"
      "        label = \"Solicitante\";"
      "        width = 30;"
      "        : edit_box { key = \"SOLICITANTE\"; width = 26; }"
      "      }"
      "      : boxed_column {"
      "        label = \"Local\";"
      "        width = 30;"
      "        : edit_box { key = \"LOCAL\"; width = 26; }"
      "      }"
      "    }"
      "    : row {"
      "      : boxed_column {"
      "        label = \"Referencias\";"
      "        width = 30;"
      "        : edit_box { key = \"REFERENCIAS\"; width = 26; }"
      "      }"
      "      : boxed_column {"
      "        label = \"Apoios\";"
      "        width = 30;"
      "        : edit_box { key = \"APOIOS\"; width = 26; }"
      "      }"
      "    }"
      "  }"
      "  : row {"
      "    : button {"
      "      key        = \"aceitar\";"
      "      label      = \"  Preencher Carimbo  \";"
      "      is_default = true;"
      "      width      = 22;"
      "    }"
      "    : button {"
      "      key       = \"cancelar\";"
      "      label     = \"  Cancelar  \";"
      "      is_cancel = true;"
      "      width     = 14;"
      "    }"
      "  }"
      "  spacer;"
      "}"
    )
  )
  
  (foreach line dcl-lines
    (write-line line f)
  )
  (close f)
  dcl-file
)

;;; ============================================================
;;; CONFIGURACOES DAS LISTAS (DROPDOWNS)
;;; ============================================================
(setq *LISTA-GRAU* (list "Nenhum" "Leve" "Medio" "Grave"))
(setq *LISTA-REGIONAL* (list "Leste" "Centro" "Oeste"))

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
  ;; [FIX v12.0] Removidas substituicoes redundantes (I->I, A->A, O->O)
  ;;             que nao tinham efeito algum no resultado.
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

;;; [REFACTOR v12.0] limpa-texto-puro e limpa-texto-objetivo foram unificadas
;;; em uma unica funcao parametrizada.
;;;
;;; Parametro modo-completo:
;;;   T   = comportamento antigo de limpa-texto-puro
;;;         (trata \P como espaco, corta em "FOLHA")
;;;   nil = comportamento antigo de limpa-texto-objetivo
;;;         (preserva \P para MText multiline, sem corte em FOLHA)
;;;
(defun limpa-texto (str modo-completo / res i c c2 j found pos)
  ;; Normalizacoes de encoding comuns aos dois modos
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

  ;; Apenas no modo completo: converte \P em espaco
  (if modo-completo
    (progn
      (setq str (str-replace "\\P" " " str))
      (setq str (str-replace "\\p" " " str))
    )
  )

  ;; Loop de limpeza de escape sequences RTF/MText
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
            ;; No modo completo, P tambem e tratado (ja convertido acima,
            ;; mas pode restar algum caso sem barra dupla)
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

  ;; Apenas no modo completo: corta em "FOLHA" (comportamento original de limpa-texto-puro)
  (if (and modo-completo (setq pos (vl-string-search "    FOLHA" res)))
    (setq res (vl-string-trim " " (substr res 1 pos)))
  )

  res
)

;;; Aliases para compatibilidade interna (usados em contextos especificos)
(defun limpa-texto-puro     (str) (limpa-texto str T))
(defun limpa-texto-objetivo (str) (limpa-texto str nil))

(defun atualiza-dxf-texto (ed novo-txt / nova-ed item)
  ;; NOTA v12.0: Esta funcao substitui grupo 1 e descarta grupos 3.
  ;; Para MTexts muito longos (>250 chars), o AutoCAD armazena o texto
  ;; em multiplos grupos 3 com grupo 1 vazio. Nesses casos, o conteudo
  ;; pode ser truncado. Verifique se (assoc 1 ed) tem valor nao-vazio
  ;; antes de confiar no resultado desta funcao em textos muito extensos.
  (setq nova-ed nil)
  (foreach item ed
    (cond
      ((= (car item) 1)
       (setq nova-ed (cons (cons 1 novo-txt) nova-ed)))
      ((= (car item) 3) nil)
      (T (setq nova-ed (cons item nova-ed)))
    )
  )
  (reverse nova-ed)
)

;;; [FIX v12.0] get-date-today: substituido itoa(fix()) por rtos para evitar
;;; falha quando CDATE retorna float com casas decimais inesperadas.
(defun get-date-today (/ str y m d)
  (setq str (rtos (getvar "CDATE") 2 0))
  (setq y (substr str 1 4))
  (setq m (substr str 5 2))
  (setq d (substr str 7 2))
  (strcat d "/" m "/" y)
)

;;; ============================================================
;;; SISTEMA CENTRAL DE LEITURA (Apenas Layout Atual)
;;; ============================================================
(defun carrega-textos-desenho (/ ss i ent ed txt linhas l l_limpa)
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

(defun extrai-objetivo-completo (/ ss i ent ed txt txt-limpo txt-norm p-dois res achou)
  (setq res "")
  (setq achou nil)
  (if (setq ss (ssget "X" (list '(0 . "TEXT,MTEXT") (cons 410 (getvar "CTAB")))))
    (progn
      (setq i 0)
      (while (and (< i (sslength ss)) (not achou))
        (setq ent (ssname ss i))
        (setq txt (get-full-text (entget ent)))
        
        (setq txt (str-replace "\n" "\\P" (str-replace "\r" "" txt)))
        
        (setq txt-limpo (limpa-texto-objetivo txt))
        (setq txt-norm (normaliza-busca txt-limpo))
        (if (vl-string-search "OBJETIV" txt-norm)
          (progn
            (setq p-dois (vl-string-search ":" txt-limpo))
            (if p-dois
              (setq res (vl-string-trim " " (substr txt-limpo (+ p-dois 2))))
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
      (setq i 0)
      (setq achou nil)
      (while (and (< i (length lista)) (not achou))
        (setq l_limpo (normaliza-busca (nth i lista)))
        
        (if (or (wcmatch v_limpo (strcat "*" l_limpo "*"))
                (wcmatch l_limpo (strcat "*" v_limpo "*"))
                (= v_limpo l_limpo))
          (progn
            (set_tile chave_dcl (itoa i))
            (setq achou T)
          )
        )
        (setq i (1+ i))
      )
    )
  )
)

;;; ============================================================
;;; PARSER EXTERNO DA OS (Sincronizado Base 0)
;;; ============================================================
(defun normaliza-pipes (texto / resultado)
  (setq resultado (str-replace "|" " " texto))
  (setq resultado (str-replace (chr 10) " " resultado))
  (setq resultado (str-replace (chr 13) "" resultado))
  
  (setq resultado (str-replace (strcat (chr 194) (chr 160)) " " resultado))
  (setq resultado (str-replace (chr 160) " " resultado))
  
  (setq resultado (str-replace (strcat (chr 194) (chr 176)) (chr 176) resultado))
  (setq resultado (str-replace (strcat (chr 194) (chr 186)) (chr 186) resultado))
  
  (setq resultado (str-replace (strcat "ENDERE" (strcat (chr 195) (chr 135)) "O:") "ENDERECO:" resultado))
  (setq resultado (str-replace (strcat "ENDERE" (strcat (chr 195) (chr 167)) "O:") "ENDERECO:" resultado))
  (setq resultado (str-replace (strcat "ENDERE" (chr 199) "O:") "ENDERECO:" resultado))
  (setq resultado (str-replace (strcat "ENDERE" (chr 231) "O:") "ENDERECO:" resultado))
  (setq resultado (str-replace "ENDEREÇO:" "ENDERECO:" resultado))

  (setq resultado (str-replace (strcat "OR" (strcat (chr 195) (chr 135)) "AMENTO:") "ORCAMENTO:" resultado))
  (setq resultado (str-replace (strcat "OR" (strcat (chr 195) (chr 167)) "AMENTO:") "ORCAMENTO:" resultado))
  (setq resultado (str-replace "ORÇAMENTO:" "ORCAMENTO:" resultado))
  (setq resultado (str-replace (strcat "SERVI" (strcat (chr 195) (chr 135)) "O:") "SERVICO:" resultado))
  (setq resultado (str-replace (strcat "SERVI" (strcat (chr 195) (chr 167)) "O:") "SERVICO:" resultado))
  (setq resultado (str-replace "SERVIÇO:" "SERVICO:" resultado))

  (while (vl-string-search "  " resultado)
    (setq resultado (str-replace "  " " " resultado))
  )
  
  (setq resultado (str-replace (strcat "N" (chr 186) " OBRA:") "NOBS:" resultado))
  (setq resultado (str-replace (strcat "N" (chr 176) " OBRA:") "NOBS:" resultado))
  resultado
)

(defun busca-chave (texto lista-chaves / ch pos melhor melhor-pos)
  (setq melhor nil)
  (setq melhor-pos 999999)
  (foreach ch lista-chaves
    (setq pos (vl-string-search ch texto))
    (if (and pos (< pos melhor-pos))
      (progn
        (setq melhor-pos pos)
        (setq melhor (list pos (strlen ch)))
      )
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
      
      (while (and (< pos-ini (strlen texto)) 
                  (wcmatch (substr texto (1+ pos-ini) 1) " ,:"))
        (setq pos-ini (1+ pos-ini))
      )
      
      (setq pos-fim (strlen texto))
      
      (foreach ch todas-delim
        (setq prox (vl-string-search ch texto pos-ini))
        (if (and prox (< prox pos-fim)) 
          (setq pos-fim prox)
        )
      )
      
      (setq resultado (substr texto (1+ pos-ini) (- pos-fim pos-ini)))
      (vl-string-trim " " resultado)
    )
  )
)

(defun aplica-os-no-dialogo (/ tx p-os p-dm p-alim p-comp p-obra p-solicitante p-local p-tec p-objetivo p-servico p-desenho p-orcamento p-regional os-dm)
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

      (princ "\n[OS] Processado com sucesso! Campos vazios foram ignorados.")
    )
  )
)

;;; ============================================================
;;; COMANDO PRINCIPAL
;;; ============================================================
(defun c:CARIMBO (/ dcl-id resultado dcl-path *MEMORIA-TEXTOS*
                    v-data v-escala v-componente v-levantamento
                    v-alimentador v-desenho v-os_dm v-grau_risco
                    v-orcamento v-regional v-servico v-objetivo v-obra
                    v-solicitante v-local v-referencias v-apoios
                    ss i ent ed txt linhas l l-limpa l-norm nova-linha
                    p-dois p-real-dois tem-chave prefixo campo-achado match frag
                    f-map valor-campo suf_folha p_f txt-final item is-objetivo txt-safe)

  (if (not (wcmatch (strcase (getvar "CTAB")) "IMPRESS*,*LAYOUT*"))
    (progn (princ "\n[BLOQUEADO] Va para uma aba LAYOUT ou IMPRESSAO primeiro.") (princ) (exit))
  )

  (setq dcl-path (cria-dcl-temp))
  (setq dcl-id (load_dialog dcl-path))
  
  (if (< dcl-id 0)
    (progn (princ "\n[ERRO] DCL nao pode ser carregado.") (vl-file-delete dcl-path) (princ) (exit))
  )

  (if (not (new_dialog "carimbo_dlg" dcl-id))
    (progn (princ "\n[ERRO] Dialogo nao encontrado.") (unload_dialog dcl-id) (vl-file-delete dcl-path) (exit))
  )

  (start_list "GRAU_RISCO") (foreach item *LISTA-GRAU* (add_list item)) (end_list) (set_tile "GRAU_RISCO" "0")
  (start_list "REGIONAL") (foreach item *LISTA-REGIONAL* (add_list item)) (end_list) (set_tile "REGIONAL" "0")

  (princ "\n[CARIMBO] Escaneando a prancha de forma otimizada...")
  (carrega-textos-desenho)
  
  (set_tile "DATA"         (extrai-campo '("DATA")))
  (set_tile "ESCALA"       (extrai-campo '("ESCALA")))
  (set_tile "ALIMENTADOR"  (extrai-campo '("ALIMENTADOR")))
  (set_tile "COMPONENTE"   (extrai-campo '("COMPONENTE")))
  (set_tile "LEVANTAMENTO" (extrai-campo '("LEVANTAMENTO")))
  (set_tile "DESENHO"      (extrai-campo '("DESENHO")))
  ;; [FIX v12.0] Busca "ORCAMENTO" ja normalizado (sem cedilha) em vez dos fragmentos
  ;; "OR" + "AMENTO" que podiam capturar campos errados acidentalmente.
  (set_tile "ORCAMENTO"    (extrai-campo '("ORCAMENTO")))
  (set_tile "OS_DM"        (extrai-campo '("OS" "DM")))
  (set_tile "OBRA"         (extrai-campo '("OBRA N")))
  (set_tile "SERVICO"      (extrai-campo '("SERVI")))
  (set_tile "SOLICITANTE"  (extrai-campo '("SOLICITANTE")))
  (set_tile "LOCAL"        (extrai-campo '("LOCAL")))
  (set_tile "APOIOS"       (extrai-campo '("APOIOS")))

  ;; [NEW v12.0] Campo REFERENCIAS: se vier vazio do desenho, pre-preenche com "SEM REF"
  (setq ref-lida (extrai-campo '("REFER")))
  (if (or (not ref-lida) (= ref-lida ""))
    (progn
      (set_tile "REFERENCIAS" "SEM REF")
      (princ "\n[CARIMBO] REFERENCIAS vazio no desenho -> preenchido com SEM REF.")
    )
    (set_tile "REFERENCIAS" ref-lida)
  )
  
  (set_tile "OBJETIVO"     (extrai-objetivo-completo))
  
  (seta-popup-indice "GRAU_RISCO" (extrai-campo '("GRAU DE RISCO")) *LISTA-GRAU*)
  (seta-popup-indice "REGIONAL"   (extrai-campo '("REGIONAL")) *LISTA-REGIONAL*)
  
  (setq *MEMORIA-TEXTOS* nil)

  (action_tile "btn_colar_os" "(aplica-os-no-dialogo)")
  (action_tile "btn_hoje"     (strcat "(set_tile \"DATA\" \"" (get-date-today) "\")"))
  (action_tile "cancelar"    "(done_dialog 0)")

  (action_tile "aceitar"
    (strcat
      "(setq v-data (get_tile \"DATA\"))"
      "(setq v-escala (get_tile \"ESCALA\"))"
      "(setq v-componente (get_tile \"COMPONENTE\"))"
      "(setq v-levantamento (get_tile \"LEVANTAMENTO\"))"
      "(setq v-alimentador (get_tile \"ALIMENTADOR\"))"
      "(setq v-desenho (get_tile \"DESENHO\"))"
      "(setq v-os_dm (get_tile \"OS_DM\"))"
      "(setq v-grau_risco (nth (atoi (get_tile \"GRAU_RISCO\")) *LISTA-GRAU*))"
      "(setq v-orcamento (get_tile \"ORCAMENTO\"))"
      "(setq v-regional (nth (atoi (get_tile \"REGIONAL\")) *LISTA-REGIONAL*))"
      "(setq v-servico (get_tile \"SERVICO\"))"
      "(setq v-objetivo (get_tile \"OBJETIVO\"))"
      "(setq v-obra (get_tile \"OBRA\"))"
      "(setq v-solicitante (get_tile \"SOLICITANTE\"))"
      "(setq v-local (get_tile \"LOCAL\"))"
      "(setq v-referencias (get_tile \"REFERENCIAS\"))"
      "(setq v-apoios (get_tile \"APOIOS\"))"
      "(done_dialog 1)"
    )
  )

  (setq resultado (start_dialog))
  (unload_dialog dcl-id)
  (vl-file-delete dcl-path)

  (if (/= resultado 1) (progn (princ "\n[CARIMBO] Cancelado.") (princ) (exit)))

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
  
  (setq v-objetivo     (strcase v-objetivo))
  (setq v-objetivo     (str-replace "\\P" " " v-objetivo))
  
  (setq v-obra         (strcase v-obra))
  (setq v-solicitante  (strcase v-solicitante))
  (setq v-local        (strcase v-local))
  (setq v-referencias  (strcase v-referencias))
  (setq v-apoios       (strcase v-apoios))

  ;; [NEW v12.0] Garantia final: se o usuario apagou o campo no dialogo,
  ;; ainda assim injeta "SEM REF" no carimbo.
  (if (or (not v-referencias) (= v-referencias ""))
    (setq v-referencias "SEM REF")
  )

  (princ "\n[CARIMBO] Injetando dados em todos os carimbos do layout...")
  
  (if (setq ss (ssget "X" (list '(0 . "TEXT,MTEXT") (cons 410 (getvar "CTAB")))))
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq ent (ssname ss i))
        (setq ed (entget ent))
        (setq txt (get-full-text ed))
        
        (setq txt-safe (str-replace "\n" "\\P" (str-replace "\r" "" txt)))
        
        (setq is-objetivo nil)
        (setq l-limpa-temp (limpa-texto-objetivo txt-safe))
        (if (and (vl-string-search ":" l-limpa-temp)
                 (vl-string-search "OBJETIV" (normaliza-busca l-limpa-temp)))
          (setq is-objetivo T)
        )
        
        (if is-objetivo
          ;; --- FLUXO DO OBJETIVO ---
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
                (entmod ed)
                (entupd ent)
              )
            )
          )
          ;; --- FLUXO DOS OUTROS CAMPOS ---
          (progn
            (setq txt (str-replace "\\P" "\n" (str-replace "\\p" "\n" txt)))
            (setq linhas (str-split txt "\n"))
            (setq nova-txt nil)
            (setq modificado nil)
            
            (foreach l linhas
              (setq l-limpa (limpa-texto-puro l))
              (setq p-dois (vl-string-search ":" l-limpa))
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
                      ;; [FIX v12.0] Busca "ORCAMENTO" normalizado diretamente
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
                      
                      (setq nova-linha (strcat prefixo " " valor-campo suf_folha (if tem-chave "}" "")))
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
                (entmod ed)
                (entupd ent)
              )
            )
          )
        )
        (setq i (1+ i))
      )
    )
  )

  (princ "\n[CARIMBO] Concluido! Todas as folhas e carimbos atualizados via Varredura Dinamica.")
  (command "REGEN")
  (princ)
)

(princ "\n[CARIMBO] v12.0 carregado com Sucesso. Execute: CARIMBO\n")
(princ)
;;; EOF