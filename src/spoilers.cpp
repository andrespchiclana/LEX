#include "spoilers.hpp"
#include <iostream>
#include <cctype>
#include <algorithm> 

using namespace std;

string Analizador::nivel_to_str(Nivel n) {
    switch(n) {
        case Nivel::SIN_SPOILERS: 
            return "SIN SPOILERS";
        case Nivel::LEVE: 
            return "SPOILER LEVE";
        case Nivel::MEDIO: 
            return "SPOILER MEDIO";
        case Nivel::GRAVE: 
            return "SPOILER GRAVE";
        default: 
            return "";
    }
}

string Analizador::limpiar_str(const char* s, int len) {
    string res = "";
    for(int i=0; i<len; i++) {
        res += (char)tolower((unsigned char)s[i]);
    }
    return res;
}

void Analizador::configurar(const Config& cfg) {
    db.init(cfg);
}

void Analizador::procesar_palabra(const char* txt, int len, double mult, EstadoResena& est) {
    string p = limpiar_str(txt, len);

    // Si no tenemos título, buscamos candidatos para deducirlo
    if (!est.tiene_titulo) {
        vector<string> posibles_obras = db.buscar_obras(p);
        if (!posibles_obras.empty()) {
            for (const auto& obra : posibles_obras) {
                est.candidatos[obra]++;
            }
        }
    }

    if (db.existe_palabra(p)) {
        est.guardar_palabra(p, mult);
    }
}

void Analizador::imprimir_analisis(EstadoResena& est) {

    if (!est.tiene_titulo && !est.candidatos.empty()) {
        vector<pair<string, int>> ranking;
        for (auto const& [obra, votos] : est.candidatos) {
            ranking.push_back({obra, votos});
        }

        sort(ranking.begin(), ranking.end(), 
             [](const pair<string, int>& a, const pair<string, int>& b) {
                 return a.second > b.second;
             }
        );

        est.titulo = ranking[0].first;
        est.tiene_titulo = true; 
        est.titulo_deducido = true;
    }

    string str_tipo;
    switch(est.tipo) {
        case TipoObra::LIBRO: str_tipo = "Libro"; break;
        case TipoObra::PELICULA: str_tipo = "Pelicula"; break;
        case TipoObra::SERIE: str_tipo = "Serie"; break;
        default: str_tipo = "Desconocido"; break;
    }

    double pts_db = 0.0;
    
    if (est.tiene_titulo) {
        if (est.tipo == TipoObra::DESCONOCIDO) {
            pts_db += db.calcular_spoiler(TipoObra::PELICULA, est.palabras_vistas);
            pts_db += db.calcular_spoiler(TipoObra::LIBRO, est.palabras_vistas);
            pts_db += db.calcular_spoiler(TipoObra::SERIE, est.palabras_vistas);
        } else {            
            pts_db = db.calcular_spoiler(est.tipo, est.palabras_vistas);
        }
    }

    double total = pts_db + est.puntuacion_total;


    if(est.etiqueta != Nivel::NINGUNO) {
        switch(est.etiqueta) {
            case Nivel::SIN_SPOILERS:
                total = 0.0;
                break;
            case Nivel::LEVE:
                total = UMBRAL_LEVE;
                break;
            case Nivel::MEDIO:
                total = UMBRAL_MEDIO;
                break;
            case Nivel::GRAVE:
                total = UMBRAL_MEDIO + 1.0;
                break;
            default:
                break;
        }
    }

    cout << "\n--- ANALISIS ---\n";
    cout << "Tipo: " << str_tipo << endl;
    
    if (est.titulo_deducido && !est.candidatos.empty()) {
        cout << "Obras deducidas:" << endl;
        
        vector<pair<string, int>> ranking;
        for (auto const& [obra, votos] : est.candidatos) {
            ranking.push_back({obra, votos});
        }
        sort(ranking.begin(), ranking.end(), [](auto& a, auto& b){ return a.second > b.second; });

        for(size_t i = 0; i < ranking.size() && i < 3; ++i) {
            cout << "  " << (i+1) << ". " << ranking[i].first << " (" << ranking[i].second << " menciones)" << endl;
        }
        cout << "  -> Obra más probable: " << est.titulo << endl;

    } else if (est.tiene_titulo) {
        cout << "Obra: " << est.titulo << endl;
    } else {
        cout << "Obra: No identificada" << endl;
    }
    
    cout << "Puntuación de spoiler: " << total << endl;

    cout << "Resultado: ";
    if (est.etiqueta != Nivel::NINGUNO) {
        cout << "Spoiler declarado en la reseña: " << nivel_to_str(est.etiqueta) << endl;
    } else {
        string nivel_texto;
        if (total <= 0) {
            nivel_texto = "SIN SPOILERS";
        } else if (total <= Analizador::UMBRAL_LEVE) {
            nivel_texto = "SPOILER LEVE";
        } else if (total <= Analizador::UMBRAL_MEDIO) {
            nivel_texto = "SPOILER MEDIO";
        } else {
            nivel_texto = "SPOILER GRAVE";
        }
        cout << nivel_texto << endl;
    }
    cout << endl << endl;
}