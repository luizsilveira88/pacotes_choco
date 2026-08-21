# AGENTS.md — Pacotes Chocolatey deste repositório

Repositório de pacotes corporativos [Chocolatey](https://chocolatey.org/)(.nuspec + scripts). Instaladores vêm do share `\\179.97.96.73\repositorio$\installers\<pacote>\` (ou URL direta), sempre com validação de hash SHA256. Use sempre PT-BR para responder os prompts.

## Estrutura
- `_shared\helpers.ps1` — única fonte das funções auxiliares
- `pack.ps1` — sincroniza a helper e gera os `.nupkg`
- `template\` — modelo de novo pacote (NÃO empacotado / ignorado)
- `<pacote>\` — um pacote por pasta; versão única → direto na raiz, múltiplas versões → subpasta com a versão (ex.: `alfasim\2025.1.0\`)
- `<pacote>.<versao>.nupkg` — GERADO, nunca editar à mão

## Helper (REGRA DE OURO)
- Edite SOMENTE `_shared\helpers.ps1`; rode `.\pack.ps1 -SyncOnly` para propagar.
- Nunca crie/edite `tools\helpers.ps1` manualmente; sempre importe com `. "$toolsDir\helpers.ps1"`.
- Fornece: `Log`, `Get-Hash`, `Hash-Valid`, `Get-LegacyInstall`, `Uninstall-Legacy`, `Remove-Shortcuts`, `Move-ShortcutToPublicDesktop`, `Remove-PathTolerant`.
- Exceção: `autocad-ptbr` tem helper própria e NÃO é sincronizada.

## chocolateyinstall.ps1 (ordem fixa)
`$ErrorActionPreference='Stop'` → variáveis (`fileType`, `expectedHash`, `silentArgs`, `$packageId/Title/Version`, `$instName`, `$toolsDir`, `$network`, `$localFile`) → dot-source da helper → (opcional) remoção de legados → cópia/reuso do instalador com `Hash-Valid` → `Install-ChocolateyInstallPackage`.
- `validExitCodes` típicos: `@(0, 1, 3010, 1641)`
- Instalador local fica em `tools\` para reuso com hash
- Sempre logar com `Log`

## .nuspec
`id` minúsculo sem espaços; `version` sem prefixo `v`; `title/authors/description/tags` preenchidos; `<dependencies>` só quando necessário. Não embutir o instalador do share (evita `.nupkg` gigante).

## Build
`.\pack.ps1` (sinca+empacota) · `.\pack.ps1 -SyncOnly` (só helper) · `.\pack.ps1 -Target a,b` (pacotes específicos). Ignora `template` e não sobrescreve `autocad-ptbr`.

## Novo pacote
Copia `template\` → edita `.nuspec` → ajusta `fileType/expectedHash/silentArgs` no `chocolateyinstall.ps1` → `.\pack.ps1 -Target <nome>` → `choco install <nome> -s . -y`.

## Encoding e boas práticas
- `.ps1` em UTF-8 com BOM (sem BOM, o PS 5.1 corrompe acentos).
- Nunca edite `.nupkg`; regenere com `choco pack`/`pack.ps1`.
- Não duplique funções inline; use a helper.
- Nova versão de pacote publicado = nova subpasta, não mudar a antiga.

## Checklist
- [ ] Helper de `_shared` (nunca duplicada) e importada com `. "$toolsDir\helpers.ps1"`
- [ ] `fileType`/`expectedHash`/`silentArgs` e `validExitCodes` corretos
- [ ] `.nupkg` regenerado via `choco pack`/`pack.ps1`
- [ ] `autocad-ptbr` e `template` intocados

## Limpeza de temporários (padrão do repositório)
- Após a instalação, remova payload/extração/XML com `Remove-PathTolerant` (helper). NUNCA `Remove-Item -Recurse -Force` direto sob `$ErrorActionPreference='Stop'` (arquivo em uso derruba o pacote).
- `Remove-PathTolerant` tenta 3 vezes com espera; se ainda falhar, loga aviso e mantém o arquivo para diagnóstico — o pacote continua instalado.
- Instaladores assíncronos (ex.: Office Click-to-Run com `setup.exe /configure`) retornam antes do fim: aguarde os processos `OfficeClickToRun`/`OfficeC2RClient` terminar antes de limpar (ver `office-2024`).
