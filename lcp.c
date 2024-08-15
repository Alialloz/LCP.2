#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "checksum.h"
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

#define MSG_ERR_B "Seul l'option -b est supportée\n"
#define MSG_ERR_TAILLE "negatif ou nul >0\n"
#define MSG_ERR_USAGE "Usage: lcp [-b taille] source... destination\n"
#define MSG_ERR_IMPAIR "pair\n"
#define MSG_ERR_TYPE "La source doit être un fichier\n"

/**
Programme permettant de copier un fichier source vers un fichier ou répertoire destination.
Utilise les sockets pour faire le transfert de données.
Si le fichier destination existe déja, le programme se charge de faire une copie paresseuse du document source.

Réalisé par :

-EID Luigi 
-NAYERI POOR Ali 
**/

/**
Vérifie si l'argument qu'on est en train de lire est le dernier argument et/ou que le prochain argument est le dernier
Retourne 1 si l'argument est invalide et se trouve à un endroit où il n'est pas sensé être
retourne 0 si l'argument est valide
**/
int verifDernierArg(int i, int argc, int finOptions, int considererOption)
{
	if (((i + 1) >= (argc - 1)) || (finOptions == 1 && considererOption == 1))
	{
		return (1);
	}
	return (0);
}

/**
Verifier si le nom entré en paramètre est un fichier régulier ou non.
Retourne 0 si ce n'est pas un fichier régulier. Sinon autre que 0.
**/
int estFichier(const char *nom)
{
	struct stat destination;
	stat(nom, &destination);
	return S_ISREG(destination.st_mode);
}

/**
Verifier si le nom entré en paramètre est un répertoire ou non.
Retourne 0 si ce n'est pas un répertoire. Sinon autre que 0.
**/
int estRepertoire(const char *nom)
{
	struct stat destination;
	stat(nom, &destination);
	return S_ISDIR(destination.st_mode);
}

/**
Verifier si les argurments entrés par l'utilisateur sont corrects.
Retourne 1 si erreur 0 si le fonctionnement est correct.
**/
int verifArg(int *taille, int *indiceFichier, char **argv, int argc)
{
	int finOptions = 0, tailleSpecifie = 0;
	for (int i = 1; i < argc - 1; i++)
	{
		if ((strcmp(argv[i], "-b") == 0))
		{
			if (verifDernierArg(i, argc, finOptions, 1) == 1 || tailleSpecifie == 1)
			{
				if (atoi(argv[i + 1]) != 0)
				{
					fprintf(stderr, "%s", MSG_ERR_USAGE);
					return (1);
				}
				if (estFichier(argv[i]) != 0)
				{
					tailleSpecifie = 1;
					if (*indiceFichier == 0)
					{
						*indiceFichier = i;
						finOptions = 1;
					}
				}
				else
				{
					fprintf(stderr, "%s", MSG_ERR_USAGE);
					return (1);
				}
			}
			else
			{
				if (tailleSpecifie == 0)
				{
					*taille = atoi(argv[++i]);
					if (*taille <= 0)
					{
						fprintf(stderr, "%s", MSG_ERR_TAILLE);
						return (1);
					}
					else if (*taille % 2 != 0)
					{
						fprintf(stderr, "%s", MSG_ERR_IMPAIR);
						return (1);
					}
					tailleSpecifie = 1;
				}
			}
		}
		else if (((strcmp(argv[i], "--") == 0)))
		{
			if (verifDernierArg(i, argc, finOptions, 1) == 1)
			{
				if (estFichier(argv[i]) != 0)
				{
					if (*indiceFichier == 0)
					{
						*indiceFichier = i;
					}
				}
				else
				{
					fprintf(stderr, "%s", MSG_ERR_USAGE);
					return (1);
				}
			}
			finOptions = 1;
		}
		else
		{
			if (*indiceFichier == 0)
			{
				if (estFichier(argv[i]) == 0)
				{
					fprintf(stderr, "%s", MSG_ERR_USAGE);
					return (1);
				}
				if (verifDernierArg((i - 1), argc, finOptions, 0) != 1)
				{
					*indiceFichier = i;
					finOptions = 1;
				}
				else
				{
					fprintf(stderr, "%s", MSG_ERR_USAGE);
					return (1);
				}
			}
			else if (estFichier(argv[i]) == 0 || estRepertoire(argv[i]) == 0)
			{
				fprintf(stderr, "%s", MSG_ERR_USAGE);
				return (1);
			}
		}
	}
	if (*indiceFichier == 0)
	{
		fprintf(stderr, "%s", MSG_ERR_USAGE);
		return (1);
	}
	return (0);
}

/**
Calcule et retourne la taille d'un fichier.
Retourne la taille du fichier(nombre de caractères).
**/
int tailleFichier(const char *nom, struct stat sb)
{
	if (stat(nom, &sb) == -1)
	{
		perror("stat");
		exit(1);
	}
	else
		return ((sb.st_size));
}

/**
Setup le fichier de destination en le créant ou le truncate, selon ce qui est préférable.
Close le fichier pour plus de sécurité (peut être retourner la valeur du descripeur au lieu de fermer)
**/
void setupDestination(const char *nom)
{
	int fdesti = open(nom, O_RDWR | O_CREAT, 0644);
	if (fdesti == -1)
	{
		perror("Desti Error :");
	}
	close(fdesti);
}

/**
Début des communications. On crée 2 pipes et on les partagent à l'aide d'un fork.
Retourne 0 lorsque la communication a été terminé
**/
int debutCommunication(int fsource, char *desti, int taille, int tailleSource, int tailleDesti)
{
	int parentFils[2], filsParent[2];
	pipe(parentFils);
	pipe(filsParent);
	pid_t pid = fork();
	if (pid == 0)
	{
		// Child
		int fileSize, fdesti, tailleBloc;
		close(parentFils[1]);
		close(filsParent[0]);
		int len = read(parentFils[0], &fileSize, sizeof(int));
		if (len < 0)
		{
			perror("Child: Failed to read data from pipe");
			exit(EXIT_FAILURE);
		}
		else if (len == 0)
		{
			fprintf(stderr, "Child: Read EOF from pipe");
		}
		else
		{
			if (fileSize > tailleSource)
			{
				fdesti = open(desti, O_RDWR | O_TRUNC, 0644);
			}
			else
			{
				fdesti = open(desti, O_RDWR);
			}
		}
		while (read(parentFils[0], &tailleBloc, sizeof(int)) > 0)
		{
			int byteDesti;
			char bufDesti[tailleBloc], bufSource[tailleBloc];
			uint32_t byte1, byte2;
			byteDesti = read(fdesti, bufDesti, tailleBloc);
			byte2 = fletcher32((uint16_t *)bufDesti, tailleBloc);
			if (read(parentFils[0], &byte1, sizeof(uint32_t)) > 0)
			{
				int resultat;
				if (byte1 != byte2)
				{
					lseek(fdesti, -byteDesti, SEEK_CUR);
					resultat = 1;
					write(filsParent[1], &resultat, sizeof(int));
					if (read(parentFils[0], bufSource, sizeof(bufSource)) > 0)
					{
						write(fdesti, bufSource, tailleBloc);
					}
				}
				else
				{
					resultat = 0;
					write(filsParent[1], &resultat, sizeof(int));
				}
			}
		}
		close(filsParent[1]);
		close(parentFils[0]);
	}
	else
	{
		// Parent
		int estFin = 0, curPos = 0;
		char bufSource[taille];
		uint32_t byte1;
		close(parentFils[0]);
		close(filsParent[1]);
		write(parentFils[1], &tailleDesti, sizeof(tailleDesti));
		while (estFin != 1)
		{
			if ((curPos + taille) > tailleSource)
			{
				taille = (tailleSource - curPos);
			}
			write(parentFils[1], &taille, sizeof(int));
			read(fsource, bufSource, taille);
			byte1 = fletcher32((uint16_t *)bufSource, taille);
			write(parentFils[1], &byte1, sizeof(uint32_t));
			int resultat;
			if (read(filsParent[0], &resultat, sizeof(int)) > 0)
			{
				if (resultat == 1)
				{
					write(parentFils[1], bufSource, sizeof(bufSource));
				}
			}
			curPos = curPos + taille;
			if (curPos >= tailleSource)
			{
				estFin = 1;
			}
		}
		close(filsParent[0]);
		close(parentFils[1]);
		waitpid(pid, NULL, 0);
	}
	return 0;
}

/**
Prépare le fichier à copier en mettant à jour plusieurs des informations
que d'autres méthodes vont utilise.
**/
void copierFichier(char *source, char *desti, int taille)
{
	int tailleSource, tailleDesti, fsource;
	char *nomSource;
	struct stat sb, sb2;

	char *ptr = strrchr(source, '/');
	if (ptr != NULL)
	{
		nomSource = ptr + 1;
	}
	else
	{
		nomSource = source;
	}

	tailleSource = tailleFichier(source, sb);
	fsource = open(source, O_RDWR);
	if (fsource == -1)
	{
		perror("Source Error :");
	}

	char *cheminFichierDesti = desti;
	if (estRepertoire(desti) != 0)
	{
		if (desti[strlen(desti) - 1] != '/')
		{
			cheminFichierDesti = strcat(desti, "/");
		}
		cheminFichierDesti = strcat(desti, nomSource);
		setupDestination(cheminFichierDesti);
	}
	else if (stat(cheminFichierDesti, &sb2) == -1)
	{
		setupDestination(cheminFichierDesti);
	}

	tailleDesti = tailleFichier(desti, sb2);
	debutCommunication(fsource, cheminFichierDesti, taille, tailleSource, tailleDesti);
}

/**
Code principal du fichier
Appel la validation, crée une liste de fichiers et appelle le copieur pour chacun d'entre eux.
**/
int main(int argc, char *argv[])
{
	int taille = 32, indiceFichier = 0;

	if (argc < 3)
	{
		fprintf(stderr, "%s", MSG_ERR_USAGE);
		exit(1);
	}
	else
	{
		if (verifArg(&taille, &indiceFichier, argv, argc) != 0)
		{
			exit(1);
		}
	}

	int nbFichierCP = (argc - 1 - indiceFichier);
	char *listeFichiers[nbFichierCP];
	for (int i = 0; i < nbFichierCP; i++)
	{
		listeFichiers[i] = argv[indiceFichier + i];
	}
	for (int i = 0; i < nbFichierCP; i++)
	{
		copierFichier(listeFichiers[i], argv[argc - 1], taille);
	}

	return 0;
}
