# Taxe au gigaoctet — POC de simulation

Ce dépôt contient un proof of concept (POC) qui estime, à partir d’un volume de données téléchargées, le montant brut théorique associé à l’amendement n° I-1358 au projet de loi de finances pour 2027.

> État au 2 novembre 2026 : l’amendement a été adopté en séance à l’Assemblée nationale le 30 octobre 2026, mais ne constitue pas une loi en vigueur.

## Ce que simule le script

L’amendement prévoit une taxe de **0,055 € par gigaoctet** de données numériques émises vers des abonnés internet en France.

Le script affiche :

- le nombre de téléchargements et le volume cumulé ;
- le débit moyen observé ;
- une projection du montant brut théorique sur 1 heure, 1 semaine, 1 mois et 1 an.

Le calcul est uniquement illustratif : `volume téléchargé × 0,055 €`.

## Limites importantes

Le script ne calcule pas la taxe effectivement due :

- le texte prévoit un plafond fixé au maximum à 15 % du chiffre d’affaires réalisé en France par l’émetteur, ou 2 % de son chiffre d’affaires total ;
- le redevable envisagé est l’émetteur du contenu, et non l’internaute, le FAI ou l’auteur de l’amendement ;
- l’amendement n’est pas, à ce stade, une loi applicable ;
- la projection dépend du débit et de l’URL testée.

## Utilisation

Prérequis : macOS ou Linux, avec `awk` et `curl` 8.4.0 ou ultérieur lorsque `COUT_MAX_EUR` est activé.

```sh
cp .env.example .env
# Éditez .env : URL, DELAI_SECONDES et COUT_MAX_EUR.
chmod +x taxe.sh
./taxe.sh
```

La configuration est lue dans `.env`, qui n’est pas publié. Définissez une `URL` vers une ressource que vous contrôlez ou pour laquelle vous disposez d’une autorisation explicite. Le délai par défaut est de 10 secondes et le plafond de coût brut théorique de 1 €. Vous pouvez régler `DELAI_SECONDES=0` ou `COUT_MAX_EUR=0`, mais ce n’est pas recommandé.

Arrêtez le script avec `Ctrl+C`.

## Sources

- [Amendement n° I-1358 — Assemblée nationale](https://www.assemblee-nationale.fr/dyn/17/amendements/3210A/AN/1358)
- [Projet de loi de finances pour 2027](https://www.assemblee-nationale.fr/dyn/17/textes/l17b3210_projet-loi)
