#ifndef SPOILER_DB_HPP
#define SPOILER_DB_HPP

#include <string>
#include <vector>
#include <map>
#include <set>
#include "estado_resena.hpp"

using namespace std;

struct Config {
    string ruta_pelis;
    string ruta_series;
    string ruta_libros;
    string ruta_nombres;
};

struct SpoilersCargados {
    vector<string> spoiler;
    double puntos;                             
};

class BaseDatos {
    private:
        vector<SpoilersCargados> db_pelis;
        vector<SpoilersCargados> db_series;
        vector<SpoilersCargados> db_libros;
        
        multimap<string, string> db_nombres; 
        set<string> palabras_vistas;

        void leer_csv_spoilers(const string& ruta, vector<SpoilersCargados>& destino);
        void leer_csv_nombres(const string& ruta);

    public:
        void init(const Config& cfg);
        
        vector<string> buscar_obras(const string& nombre) const;
                
        bool existe_palabra(const string& p) const;

        double calcular_spoiler(TipoObra tipo, const map<string, double>& vistas);
};

#endif