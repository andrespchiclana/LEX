#include "spoiler_db.hpp"
#include <fstream>
#include <sstream>
#include <algorithm>
#include <cctype>
#include <iostream>

using namespace std;

static void limpiar_espacios(string& s) {
    while (!s.empty() && isspace(s.back())) {
        s.pop_back();
    }
    while (!s.empty() && isspace(s.front())) {
        s.erase(s.begin());
    }
}

static void a_minusculas(string& s) {
    for (char& c : s) {
        c = tolower((unsigned char)c);
    }
}

static vector<string> split(const string& txt) {
    vector<string> res;
    stringstream ss(txt);
    string p;
    
    while (ss >> p) {
        res.push_back(p);
    }
    return res;
}


void BaseDatos::leer_csv_spoilers(const string& ruta, vector<SpoilersCargados>& destino) {
    ifstream f(ruta);
    if (!f.is_open()) {
        return;
    }

    string linea;
    while (getline(f, linea)) {
        if (linea.empty() || linea[0] == '#') {
            continue;
        }
        
        stringstream ss(linea);
        string parte;
        vector<string> cols;

        while (getline(ss, parte, ';')) {
            cols.push_back(parte);
        }

        if (cols.size() >= 3) {
            SpoilersCargados temp;
            temp.puntos = stod(cols[2]); 

            string temp_str = cols[1];
            a_minusculas(temp_str);
            temp.spoiler = split(temp_str);
            
            for(const auto& w : temp.spoiler) {
                palabras_vistas.insert(w);
            }
            destino.push_back(temp);
        }
    }
}

void BaseDatos::leer_csv_nombres(const string& ruta) {
    ifstream f(ruta);
    if (!f.is_open()) {
        return;
    }

    string linea;
    while (getline(f, linea)) {
        if (linea.empty() || linea[0] == '#') {
            continue;
        }
        
        stringstream ss(linea);
        string nombre, obra;
        
        if (getline(ss, nombre, ';') && getline(ss, obra)) {
            limpiar_espacios(nombre);
            limpiar_espacios(obra);
            a_minusculas(nombre);
            
            if (!nombre.empty() && !obra.empty()) {
                db_nombres.insert({nombre, obra});
                palabras_vistas.insert(nombre); 
            }
        }
    }
}

void BaseDatos::init(const Config& cfg) {
    if (!cfg.ruta_pelis.empty()) {
        leer_csv_spoilers(cfg.ruta_pelis, db_pelis);
    }
    if (!cfg.ruta_series.empty()) {
        leer_csv_spoilers(cfg.ruta_series, db_series);
    }
    if (!cfg.ruta_libros.empty()) {
        leer_csv_spoilers(cfg.ruta_libros, db_libros);
    }
    if (!cfg.ruta_nombres.empty()) {
        leer_csv_nombres(cfg.ruta_nombres);
    }
}

vector<string> BaseDatos::buscar_obras(const string& nombre) const {
    vector<string> resultados;
    auto range = db_nombres.equal_range(nombre);
    
    for (auto it = range.first; it != range.second; ++it) {
        resultados.push_back(it->second);
    }
    return resultados;
}

bool BaseDatos::existe_palabra(const string& p) const {
    return palabras_vistas.find(p) != palabras_vistas.end();
}

double BaseDatos::calcular_spoiler(TipoObra tipo, const map<string, double>& vistas) {
    const vector<SpoilersCargados>* lista = nullptr;

    if (tipo == TipoObra::LIBRO) {
        lista = &db_libros;
    } else if (tipo == TipoObra::PELICULA) {
        lista = &db_pelis;
    } else if (tipo == TipoObra::SERIE) {
        lista = &db_series;
    } else {
        return 0.0;
    }

    double total = 0.0;

    for (const auto& aux : *lista) {
        int hits = 0;
        double max_mult = 1.0;

        for (const string& k : aux.spoiler) {
            auto it = vistas.find(k);
            if (it != vistas.end()) {
                hits++;
                if (it->second > max_mult) {
                    max_mult = it->second;
                }
            }
        }

        if (aux.spoiler.empty()) {
            continue;
        }

        double porcentaje = (double)hits / aux.spoiler.size();
        bool activado = (aux.spoiler.size() == 1) ? (hits == 1) : (porcentaje >= 0.5);

        if (activado) {
            total += (aux.puntos * max_mult);
        }
    }
    return total;
}
