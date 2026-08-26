# Pacotes Choco

Este repositório contém pacotes [Chocolatey](https://chocolatey.org/) (`.nuspec` + scripts de instalação) utilizados para automatizar a instalação e atualização de softwares corporativos via `choco install`.

## Estrutura do repositório

Cada pasta na raiz representa um pacote Chocolatey. Pacotes que já tiveram mais de uma versão publicada possuem subpastas nomeadas com o número da versão (ex.: `alfasim/2025.1.0`, `alfasim/2025.2.1`), cada uma contendo seu próprio `.nuspec` e `.nupkg`. Pacotes com versão única mantêm os arquivos diretamente na pasta do pacote.

Estrutura típica de um pacote:

```
<pacote>/
├── <pacote>.nuspec              # Metadados do pacote (id, versão, título, autor, descrição, dependências)
├── <pacote>.<versao>.nupkg      # Pacote empacotado (gerado via `choco pack`)
└── tools/
    ├── chocolateyinstall.ps1    # Script de instalação
    ├── chocolateyuninstall.ps1  # Script de desinstalação (quando aplicável)
    └── helpers.ps1                # Funções auxiliares (log, validação de hash, etc.) — sincronizado via pack.ps1
```

As funções auxiliares (log, validação de hash, remoção de legados, etc.) têm **fonte única**
em `_shared/helpers.ps1` e são sincronizadas para dentro de cada pacote (`tools/helpers.ps1`)
pelo script `pack.ps1`. Não edite `tools/helpers.ps1` manualmente: altere `_shared/helpers.ps1`
e rode `.\pack.ps1 -SyncOnly`. O pacote `autocad-ptbr` tem helper específica própria e é
excluído dessa sincronização.

A maioria dos scripts de instalação segue o mesmo padrão:
1. Busca o instalador em um compartilhamento de rede (`\\179.97.96.73\repositorio$\installers\<pacote>\`);
2. Reutiliza uma cópia local caso o hash SHA256 já corresponda ao esperado;
3. Copia o instalador da rede quando necessário e valida sua integridade;
4. Executa a instalação silenciosa via `Install-ChocolateyInstallPackage`.

A pasta `template/` serve como modelo (`nome_pacote`, versão `0.0.0`) para a criação de novos pacotes seguindo o mesmo padrão, e não é listada como pacote real na tabela abaixo.

## Pacotes disponíveis

| Pacote | Título | Versão(ões) | Autor/Fornecedor |
|---|---|---|---|
| `alfasim` | ALFAsim | 2025.1.0<br>2025.2.1 | ESSS |
| `astrometrica` | Astrometrica | 4.10.6.453 | IASC |
| `autocad-ptbr` | AutoCAD PT-BR | 2026 | Autodesk |
| `cmg` | CMG | 2025.30.0<br>2026.11.0 | CMG |
| `digifort` | Digifort | 7.3.0 | Beicip |
| `flowax` | FloWax | 7.6.0 | KBC |
| `kbclicensetester` | KBC License Tester | 7.0.7500 | KBC |
| `maximus` | Maximus | 7.6.0 | KBC |
| `multiflash` | MultiFlash | 7.6.13 | KBC |
| `olga` | Olga | 2026.1.0 | SLB |
| `openflow` | OpenFlow | 2024.0.0 (sempre a versão mais recente) | Beicip |
| `openflow-2023` | OpenFlow 2023 | 2023.0.0 | Beicip |
| `openflow-2024` | OpenFlow 2024 | 2024.0.0 | Beicip |
| `office-2024` | Microsoft Office LTSC 2024 | 2024.0.0 | Microsoft |
| `opm-flow` | OPM Flow | 2026.4.1 | Open Porous Media Initiative |
| `petrel` | Petrel | 2024.0.0 | SLB |
| `petrosim` | Petro-Sim | 7.6.0 | — |
| `pipesim` | Pipesim | 2026.1.388 | — |

## Como usar

### Empacotar (gerar o `.nupkg`)

O comando recomendado é o `pack.ps1` da raiz, que **sincroniza a helper compartilhada** antes de empacotar:

```powershell
cd c:\dev\pacotes_choco

.\pack.ps1                      # sincroniza _shared/helpers.ps1 e gera todos os .nupkg
.\pack.ps1 -SyncOnly            # apenas propaga a helper, sem empacotar
.\pack.ps1 -Target flowax,petrel   # somente alguns pacotes
```

Também é possível empacotar um pacote isoladamente com o `choco pack` tradicional:

```powershell
cd <pacote>
choco pack
```

### Instalar localmente a partir do `.nupkg`

```powershell
choco install <pacote> -s . -y
```

### Instalar diretamente pela pasta de fontes

```powershell
choco install <pacote> --source="'C:\dev\pacotes_choco\<pacote>'" -y
```

## Criando um novo pacote

1. Copie a pasta `template/` para uma nova pasta com o nome do pacote (em minúsculas, sem espaços).
2. Renomeie e edite o `template.nuspec` (`id`, `version`, `title`, `authors`, `description`, `tags`).
3. Ajuste `tools/chocolateyinstall.ps1` com o tipo de arquivo (`fileType`), o hash SHA256 esperado (`expectedHash`) e os argumentos de instalação silenciosa (`silentArgs`).
4. Gere o pacote com `.\pack.ps1 -Target <nome>` (sincroniza a helper e gera o `.nupkg`) ou `choco pack` dentro da pasta do novo pacote.

## Requisitos

- [Chocolatey CLI](https://chocolatey.org/install) instalado na máquina que fará o empacotamento/instalação.
- Acesso ao compartilhamento de rede `\\179.97.96.73\repositorio$\installers\` para os pacotes que buscam o instalador remotamente.
