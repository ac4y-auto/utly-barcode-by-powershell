# Barcode Typer

Vonalkód szimulátor WMS teszteléshez. Globális hotkey-vel gépeli be a vonalkódokat bármelyik ablakba (pl. böngésző input mező).

## Indítás

```powershell
powershell -ExecutionPolicy Bypass -File barcode-typer.ps1
```

Vagy: jobb klikk a fájlra -> **Run with PowerShell**

## Hotkey-k

| Billentyű | Funkció |
|-----------|---------|
| **F9** | Begépeli a következő vonalkódot az aktív mezőbe |
| **F8** | Törli az aktív mező tartalmát (Select All + Delete) |

A hotkey-k **globálisan** működnek - bármelyik ablakban nyomd meg, nem kell a Barcode Typer-re fókuszálni.

## Használat

1. Indítsd el a scriptet
2. Kattints a célmezőbe (pl. böngésző input)
3. Nyomd meg az **F9**-et - a következő vonalkódot begépeli
4. Ha rossz mezőbe írta, nyomj **F8**-at a törléshez

## Vonalkód lista

- A lista a `codes.txt` fájlban tárolódik (a script melletti mappában)
- Ha a fájl nem létezik, létrehozza az alapértelmezett kódokkal
- Ha szerkeszted a listát az ablakban, automatikusan menti a fájlba
- **Klikk egy sorra** a listában: onnan folytatja a sort
- **Load .txt** gomb: külön fájlból tölthetsz be kódokat
- **Reset** gomb: visszaáll az első kódra

## Opciók

- **Enter küldése a kód után** - a vonalkód után automatikusan Enter-t küld (alapból be)
- **Lista ismétlése (loop)** - a lista végénél újrakezdi az elejéről (alapból be)
- **Delay (ms)** - várakozás a gépelés előtt (alapból 50ms)
