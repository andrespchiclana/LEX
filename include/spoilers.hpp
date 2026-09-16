#ifndef SPOILERS_HPP
#define SPOILERS_HPP

#include <string>
#include "spoiler_db.hpp"
#include "estado_resena.hpp"

using namespace std;

class Analizador {
    private:
        BaseDatos db;
        
        string nivel_to_str(Nivel n);
        string limpiar_str(const char* s, int len);

    public:

        static constexpr double UMBRAL_LEVE = 3.0;
        static constexpr double UMBRAL_MEDIO = 5.0;

        void configurar(const Config& cfg);

        void procesar_palabra(const char* txt, int len, double mult, EstadoResena& est);

        void imprimir_analisis(EstadoResena& est);
};

#endif