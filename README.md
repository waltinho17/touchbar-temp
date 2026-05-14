# TouchBar Temp

**Mostra a temperatura do CPU diretamente na Touch Bar do Mac.**  
**Displays CPU temperature directly in your Mac's Touch Bar.**

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2-green)
![Intel](https://img.shields.io/badge/Intel-supported-lightgrey)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow)
[![GitHub](https://img.shields.io/github/stars/waltinho17/touchbar-temp?style=social)](https://github.com/waltinho17/touchbar-temp)

---

## 🌡️ O que faz / What it does

- Exibe a temperatura do CPU na Touch Bar em tempo real (atualiza a cada 3 segundos)
- Fonte SF Pro Rounded Heavy — integrada ao visual nativo do macOS
- Cores automáticas: 🟢 Normal · 🟠 Quente · 🔴 Crítico
- Opção de desativar as cores (branco nativo da Touch Bar)
- Sem ícone no Dock — aparece só na barra de menus
- Compatível com MacBook Pro com Touch Bar (Intel e Apple Silicon M1/M2)

---

- Displays CPU temperature in the Touch Bar in real time (updates every 3 seconds)
- SF Pro Rounded Heavy font — native macOS look
- Automatic colors: 🟢 Normal · 🟠 Warm · 🔴 Critical
- Option to disable colors (native white Touch Bar text)
- No Dock icon — lives only in the menu bar
- Compatible with Touch Bar MacBook Pro (Intel and Apple Silicon M1/M2)

---

## 🌡️ Temperaturas / Temperature thresholds

| Cor / Color | Faixa / Range |
|---|---|
| 🟢 Verde / Green | < 70 °C |
| 🟠 Laranja / Orange | 70 – 85 °C |
| 🔴 Vermelho / Red | > 85 °C |

---

## 📦 Instalação / Installation

### Opção 1 — Terminal (recomendado)

```bash
git clone https://github.com/waltinho17/touchbar-temp.git
cd touchbar-temp
make run
```

### Opção 2 — Xcode

```bash
git clone https://github.com/waltinho17/touchbar-temp.git
cd touchbar-temp
open Package.swift
```

Build & Run no Xcode (⌘R).

### Opção 3 — Release pronto

Baixe o `.app` na [página de Releases](https://github.com/waltinho17/touchbar-temp/releases), descompacte e rode no Terminal:

```bash
xattr -cr "TouchBar Temp.app"
```

Depois arraste para `/Applications` e abra normalmente.

> O `xattr -cr` remove o bloqueio do Gatekeeper (necessário por não ter assinatura de desenvolvedor pago). O código é 100% aberto.

---

## ⚙️ Como usar / How to use

1. Abra o app → o ícone 🌡️ aparece na barra de menus
2. A temperatura já aparece na Touch Bar (lado direito, área do sistema)
3. Clique no ícone da barra de menus para:
   - Ativar/desativar cores automáticas
   - Sair do app

---

1. Open the app → thermometer icon appears in the menu bar
2. Temperature shows immediately in the Touch Bar (right side, system tray area)
3. Click the menu bar icon to:
   - Toggle automatic colors
   - Quit

---

## 🔧 Requisitos / Requirements

- macOS 12 Monterey ou superior
- MacBook Pro com Touch Bar (2016–2022)
- Xcode 15+ ou Swift 5.9+ para compilar

---

## 🏗️ Arquitetura / Architecture

```
Sources/touchbar-temp/
├── main.swift              # Ponto de entrada / Entry point
├── AppDelegate.swift       # Ciclo de vida + menu bar / Lifecycle + menu bar
├── TemperatureReader.swift # Leitura SMC via IOKit / SMC reading via IOKit
└── TouchBarController.swift # NSTouchBar + display / Touch Bar display
```

Sem dependências externas. Usa apenas frameworks nativos do macOS: AppKit, IOKit, Foundation.

No external dependencies. Uses only native macOS frameworks: AppKit, IOKit, Foundation.

---

## 🤝 Contribuindo / Contributing

PRs são bem-vindos! / PRs are welcome!

Ideias para futuras versões:
- [ ] Temperatura da GPU
- [ ] Temperatura da bateria
- [ ] Personalização dos limiares de temperatura
- [ ] Lançar automaticamente no login

---

## 📄 Licença / License

MIT © [Walter Rodrigues](https://github.com/waltinho17)

---

*Keywords: macOS touch bar temperature, Mac CPU temperature monitor, Touch Bar utility, temperatura CPU Mac, monitor temperatura macbook, touchbar app temperature, MacBook Pro temperature display, Apple Silicon temperature Touch Bar*
