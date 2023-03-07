# 20220616 - [DeveloppeurPascal](https://github.com/DeveloppeurPascal)

* bogue (Mac) : correction du nom de fichier utilisé en export de la bannière (lors du second coup, le chemin apparaît en entier et se multipliait à chaque enregistrement)
* bogue : quand on créait plusieurs projets d'affilée, les informations d'enregistrement provenaient du précédent (nom de fichier du projet, nom de la bannèire). Réinitialisation des chemins par défaut et noms de fichier des boites de dialogue d'enregistrement lors de la fermeture d'un projet.
* modification du prérenseignement du chemin et nom de fichier lors de l'export d'une bannière (reprise du chemin/nom du projet par défaut)
* par défaut l'ajout d'une image se fait depuis le dossier "mes images", puis depuis le dossier de la dernière image ajoutée
* le chemin proposé lors de l'ouverture d'un projet est par défaut dans "mes documents" puis positionné sur le dossier du dernier projet ouvert
* ajout du nom du projet ouvert dans la barre de titre
* si la bannière PNG générée occupe plus de 2Mo (limite de Google Play au 2022-06-16), on envoit une exception (à défaut de pouvoir faire un JPEG de la bonne taille)
* modification des images du projet affichées à l'écran afin de gérer leur sélection / désélection
* traitement de la suppression des images du projet
* traitement de la touche "ESC" pour cliquer par défaut sur le bouton "Close" lorsqu'un projet est ouvert et sortir du programme depuis l'écran principal
* affichage en pied d'écran des touches utilisées quand on est en DEBUG (pour trouver plus facilement les racourcis clavier)
* traitement de la combinaison de touches Ctrl+S pour déclencher la sauvegarde du projet ouvert (s'il y a des trucs à sauvegarder)