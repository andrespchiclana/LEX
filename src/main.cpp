#include <iostream>
#include <limits>
#include <cstring>
#include <cstdio>
#include <string>
#include <unistd.h> 

#include "spoilers.hpp"
#include "estado_resena.hpp"

using namespace std;

EstadoResena estado;
Analizador analizador;

extern int yylex();
extern void yyrestart(FILE * archivo);
extern void reset_lex(); 

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;

    // Rutas a las bases de datos
    Config config;
    config.ruta_pelis = "data/spoilers_pelis.csv";
    config.ruta_series = "data/spoilers_series.csv";
    config.ruta_libros = "data/spoilers_libros.csv";
    config.ruta_nombres = "data/nombres_generales.csv";

    analizador.configurar(config);

    // Detectar si se ha redirigido la entrada 
    bool entrada_redirigida = !isatty(fileno(stdin));

    if (entrada_redirigida) {
        reset_lex();
        yylex(); 
        analizador.imprimir_analisis(estado);
        return 0;
    }

    // Modo interactivo
    bool terminal = true;
    while (terminal) {
        reset_lex();
        cin.clear();        
        clearerr(stdin);

        cout << "\n--- DETECTOR DE SPOILERS ---\n";
        cout << "1. Libro\n2. Pelicula\n3. Serie\n";
        cout << "Elige una opción: ";

        int tipo_obra;
        if (!(cin >> tipo_obra)) break;
        
        cin.ignore(numeric_limits<streamsize>::max(), '\n');
        
        if (tipo_obra == 1) estado.tipo = TipoObra::LIBRO;
        else if (tipo_obra == 2) estado.tipo = TipoObra::PELICULA;
        else if (tipo_obra == 3) estado.tipo = TipoObra::SERIE;
        else {
            cout << "Opción no válida, intenta de nuevo.\n";
            continue; 
        }

        cout << "Título de la obra (Enter para omitir): ";
        string titulo; 
        getline(cin, titulo);
        
        if (!titulo.empty() && titulo.back() == '\r') titulo.pop_back();
        if(!titulo.empty()) {
            estado.titulo = titulo;
            estado.tiene_titulo = true;
            estado.titulo_deducido = false;
        } else {
            estado.tiene_titulo = false;
        }

        cout << "Escribe la reseña (termina pulsando Ctrl+D):\n\n";

        yyrestart(stdin);
        yylex(); 
        analizador.imprimir_analisis(estado);

        cin.clear();
        clearerr(stdin);
        
        // Añadir más reseñas
        while (true) {
            cout << "¿Analizar otra reseña? (s/n): ";
            char respuesta;
            if (cin >> respuesta) {
                cin.ignore(numeric_limits<streamsize>::max(), '\n');
                if (respuesta == 'n' || respuesta == 'N') {
                    terminal = false;
                    break;
                } else if (respuesta == 's' || respuesta == 'S') {
                    break; 
                }
            } else {
                terminal = false;
                break;
            }
        }
    }

    return 0;
}