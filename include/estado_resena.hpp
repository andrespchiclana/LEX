#ifndef ESTADO_RESENA_HPP
#define ESTADO_RESENA_HPP

#include <string>
#include <vector>
#include <map>

using namespace std;

enum class TipoObra {
    DESCONOCIDO,
    LIBRO,
    PELICULA,
    SERIE
};

enum class Nivel {
    NINGUNO,
    SIN_SPOILERS,
    LEVE,
    MEDIO,
    GRAVE
};

struct EstadoResena {
    TipoObra tipo;
    string titulo;
    Nivel etiqueta;
    
    bool tiene_titulo;
    bool titulo_deducido;
    
    double puntuacion_total;

    map<string, double> palabras_vistas;
    map<string, int> candidatos;

    vector<string> palabras_ventana;
    vector<string> lista_spoilers; 

    EstadoResena();

    void reset();

    void guardar_palabra(const string& p, double mult = 1.0);
    void procesar_evento(const string& spoiler, double peso);
};

#endif