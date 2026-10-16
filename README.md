# Tool do listowania domen z ruchu sieciowego

Skrypt PowerShell, który z list adresów URL lub plików HAR z zakładki **Network** w DevTools wyciąga unikalne domeny i porównuje je między plikami: które są tylko w jednym pliku, które w kilku, a które we wszystkich.

## Wymagania

Windows PowerShell 5.1 (wbudowany w Windows 10/11).

## Przygotowanie list

Otwórz DevTools (F12), przejdź do zakładki **Network** i załaduj stronę. Następnie kliknij prawym przyciskiem na liście żądań i wybierz jedną z opcji:

- **Copy** → **Copy all URLs** (Chrome, Edge), a wynik wklej do pliku `.txt`, po jednym adresie w linii,
- **Save all as HAR** (Chrome, Edge, Firefox) i zapisz plik `.har`.

Format jest rozpoznawany po rozszerzeniu, więc w jednym wywołaniu można podać pliki obu typów. Plik HAR może zawierać ciasteczka i tokeny logowania, więc nie udostępniaj go.

Brane są tylko adresy `http`, `https`, `ws` i `wss`. Wpisy takie jak `data:`, `blob:` czy `chrome-extension://` są pomijane.

## Użycie

```powershell
.\run_tool.ps1 .\Lists\List1.txt .\Lists\List2.txt
.\run_tool.ps1 .\Lists\List1.txt .\Lists\List2.har
.\run_tool.ps1 .\Lists\*.txt -OutFile .\raport.txt
.\run_tool.ps1 .\Lists\*.txt -Subdomains None
```

| Parametr   | Opis |
|------------|------|
| `-Path`    | Pliki `.txt` (jeden adres URL w linii) lub `.har`. Nazwę parametru można pominąć. Przyjmuje kilka plików (po spacji lub przecinku) albo wzorzec, np. `*.txt`. |
| `-Subdomains` | Ile poziomów subdomen zostawić. `All` (domyślnie): pełne nazwy, `None`: sama domena z TLD (`cdn.google.com` → `google.com`), liczba, np. `2`: najwyżej tyle poziomów (`a.b.c.example.com` → `b.c.example.com`). Adresy IP i `localhost` zostają bez zmian. |
| `-OutFile` | Ścieżka pliku z raportem. Domyślnie `Reports\report_<data>_<godzina>.txt` obok skryptu. |

Przy `-Subdomains` granica domeny jest ustalana na podstawie [Public Suffix List](https://publicsuffix.org/) z pliku `public_suffix_list.dat`. Dzięki temu `shop.example.com.pl` daje `example.com.pl`, a nie `com.pl`. Na platformach, gdzie każdy może dostać własną subdomenę, granica przebiega o poziom niżej, więc `x.user.github.io` daje `user.github.io`, a nie `github.io`. Tak samo działa to dla `cloudfront.net`, `azurewebsites.net`, `herokuapp.com` i podobnych.

Aktualizacja listy:

```powershell
Invoke-WebRequest https://publicsuffix.org/list/public_suffix_list.dat -OutFile .\public_suffix_list.dat -UseBasicParsing
```

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

Plik `public_suffix_list.dat` pochodzi z [publicsuffix.org](https://publicsuffix.org/) i jest udostępniany na licencji [MPL-2.0](https://mozilla.org/MPL/2.0/).
