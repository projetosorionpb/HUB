# Changelog - Hub de Engenharia

Todas as mudanças notáveis no Hub de Engenharia serão documentadas neste arquivo.

O formato baseia-se em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/), e este projeto adere ao [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-02
### Adicionado
- **Sincronização Bidirecional**: O Hub agora detecta módulos que foram excluídos do `manifest.json` do GitHub e os remove automaticamente do disco local do usuário e da interface.
- **Painel de Controle Avançado**: Adicionada Opção 4 no `scripts/admin_hub.py` que permite remover um programa por completo do Hub (apaga pasta `modules/` e remove do manifest).
- `.gitignore` oficial adicionado para limpar `dist/`, `build/` e `__pycache__/` do repositório.
- Documentação técnica estendida: `ARCHITECTURE.md` e `MANIFEST_SPEC.md`.
- Constantes centralizadas (`APP_NAME`, `APP_AUTHOR`) no `config.py` para padronização.

### Alterado
- **Cleanup**: Módulo legado "Substituidor de Blocos" (45MB) que estava esquecido na pasta `dist/` foi removido.
- `README.md` reescrito do zero, focando na arquitetura, ambiente de dev e regras do sistema.
- `UPDATE_GUIDE.md` atualizado para contemplar a nova Opção 4 e o funcionamento do fluxo de deleção de ferramentas.
- O executável do PyInstaller foi enxugado com a remoção de parâmetros obsoletos no `hub.spec`.

### Removido
- Script redundante `add_module.py` foi deletado. Sua funcionalidade já é coberta (e de forma superior) pelo `admin_hub.py`.

---

## [1.0.2] - 2026-05-20
### Adicionado
- Funcionalidade de Auto-Update para o próprio `.exe` (`hub_self_updater.py`).
- Suporte a ferramentas do tipo `web` (abre URL diretamente).
- Scripts automatizados para gerenciar o manifesto de atualizações remotas.

### Alterado
- Melhoria no sistema de UI dos Cards.
- Refatoração dos workers no PyQt6.
