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
    └── helpers.ps1 / helpers-1.0.0.ps1  # Funções auxiliares (log, validação de hash, etc.)
```

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
| `openflow` | OpenFlow | 2024.0.0 | Beicip |
| `petrel` | Petrel | 2024.0.0 | SLB |
| `petrosim` | Petro-Sim | 7.6.0 | — |
| `pipesim` | Pipesim | 2026.1.388 | — |

## Como usar

### Empacotar (gerar o `.nupkg`)

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
4. Gere o pacote com `choco pack` dentro da pasta do novo pacote.

## Requisitos

- [Chocolatey CLI](https://chocolatey.org/install) instalado na máquina que fará o empacotamento/instalação.
- Acesso ao compartilhamento de rede `\\179.97.96.73\repositorio$\installers\` para os pacotes que buscam o instalador remotamente.
