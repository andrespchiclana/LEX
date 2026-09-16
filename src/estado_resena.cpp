#include "estado_resena.hpp"

EstadoResena::EstadoResena() {
    reset();
}

void EstadoResena::reset() {
    tipo = TipoObra::DESCONOCIDO;
    titulo = "";
    
    tiene_titulo = false;
    titulo_deducido = false;
    puntuacion_total = 0.0;

    palabras_vistas.clear();
    candidatos.clear();
    palabras_ventana.clear();
    lista_spoilers.clear();

    etiqueta = Nivel::NINGUNO;
}

void EstadoResena::guardar_palabra(const string& p, double mult) {
    auto it = palabras_vistas.find(p);
    if (it == palabras_vistas.end()) {
        palabras_vistas[p] = mult;
    } else {
        if (mult > it->second) {
            it->second = mult;
        }
    }
}

void EstadoResena::procesar_evento(const string& spoiler, double peso) {
    lista_spoilers.push_back(spoiler);
    puntuacion_total += peso;
}