# Tool do listowania domen z ruchu sieciowego

Skrypt PowerShell, który z list adresów URL skopiowanych z zakładki **Network** w DevTools wyciąga unikalne domeny i porównuje je między plikami: które są tylko w jednym pliku, które w kilku, a które we wszystkich.

## Wymagania

Windows PowerShell 5.1 (wbudowany w Windows 10/11).

## Przygotowanie list

1. Otwórz DevTools (F12), przejdź do zakładki **Network** i załaduj stronę.
2. Kliknij prawym przyciskiem na liście żądań i wybierz **Copy** → **Copy all URLs** (Chrome, Edge).
3. Wklej wynik do pliku `.txt`, po jednym adresie w linii.

Brane są tylko adresy `http`, `https`, `ws` i `wss`. Wpisy takie jak `data:`, `blob:` czy `chrome-extension://` są pomijane.

## Użycie

```powershell
.\run_tool.ps1 .\Lists\List1.txt .\Lists\List2.txt
.\run_tool.ps1 .\Lists\*.txt
.\run_tool.ps1 .\Lists\*.txt -OutFile .\raport.txt
```

| Parametr   | Opis |
|------------|------|
| `-Path`    | Pliki z adresami URL. Nazwę parametru można pominąć. Przyjmuje kilka plików (po spacji lub przecinku) albo wzorzec, np. `*.txt`. |
| `-OutFile` | Ścieżka pliku z raportem. Domyślnie `Reports\report_<data>_<godzina>.txt` obok skryptu. |

## Wynik

Raport jest wypisywany w konsoli oraz zapisywany do pliku. Zawiera kolejno:

1. domeny z każdego pliku,
2. domeny pogrupowane według plików, w których występują:
   - `Only in …`: tylko w jednym pliku,
   - `In … + …`: w części plików,
   - `Common to all files`: we wszystkich plikach.

   Puste grupy są pomijane.
3. `All domains`: wszystkie domeny ze wszystkich plików.

Przykład dla trzech plików:

```
==== List1.txt (3) ====
a.com
b.com
c.com

==== List2.txt (3) ====
b.com
c.com
d.com

==== List3.txt (2) ====
c.com
e.com

==== Only in List1.txt (1) ====
a.com

==== Only in List2.txt (1) ====
d.com

==== Only in List3.txt (1) ====
e.com

==== In List1.txt + List2.txt (1) ====
b.com

==== Common to all files (1) ====
c.com

==== All domains (5) ====
a.com
b.com
c.com
d.com
e.com
```

## Licencja

MIT, szczegóły w pliku [LICENSE](LICENSE).
