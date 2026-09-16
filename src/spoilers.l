%option noyywrap
%option nounput noinput nodebug

%{
#include <string>
#include <deque>
#include <vector>
#include <algorithm>
#include <iostream> 
#include "estado_resena.hpp"
#include "spoilers.hpp"

using namespace std;

extern EstadoResena estado;
extern Analizador analizador;

// Pesos definidos
constexpr double PESO_AVISO_EXPLICITO = 4.0;
constexpr double PESO_FR_MUERE_PROTAG = 3.5;
constexpr double PESO_FR_ASESINO_ID = 3.5;
constexpr double PESO_FR_VILLANO_ID = 3.5;
constexpr double PESO_FR_TODO_SUENO = 3.0;
constexpr double PESO_FR_GIRO_FINAL = 3.0;
constexpr double PESO_FR_FINAL_INESP = 3.0;
constexpr double PESO_FR_PADRE_ES = 3.0;
constexpr double PESO_FR_TRAIDOR_ES = 3.0;
constexpr double PESO_FR_REVELACION = 2.5; 
constexpr double PESO_FR_TRAMPA = 2.2;
constexpr double PESO_KW_VIOLENCIA = 2.0; 
constexpr double PESO_KW_TRAMA = 2.0; 
constexpr double PESO_KW_ACCION = 1.0; 
constexpr double PESO_KW_PISTA = 0.6; 
constexpr double PESO_KW_AVISO_DEBIL = 0.8; 

// Funciones auxiliares


static string limpiar_salto_linea(string s) { 
    while (!s.empty() && (s.back() == '\n' || s.back() == '\r' || s.back() == ' ' || s.back() == '\t')) {
        s.pop_back();
    }
    return s;
}

static string valor_dos_puntos(const string& s) {
    auto p = s.find(':');
    if (p == string::npos) {
        return "";
    }
    
    string v = s.substr(p + 1);
    
    while (!v.empty() && (v.front() == ' ' || v.front() == '\t')) {
        v.erase(v.begin());
    }
    
    return limpiar_salto_linea(v);
}

static int contar_tokens(const char* t, int n) {
    int cnt = 0;
    bool dentro = false;
    
    for (int i = 0; i < n; ++i) {
        bool sep = (t[i] == ' ' || t[i] == '\t' || t[i] == '\n' || t[i] == '\r');
        
        if (!sep && !dentro) { 
            cnt++; 
            dentro = true; 
        }
        
        if (sep) {
            dentro = false;
        }
    }
    return cnt;
}

// Logica de ventanas (Peligro y Negacion)

static int ventana_peligro = 0; 
static int ventana_negacion = 0; 

static const int TAM_VENTANA = 8;

static void activar_peligro() { 
    ventana_peligro = TAM_VENTANA; 
}

static void activar_negacion() {
    ventana_negacion = TAM_VENTANA;
}

static void actualizar_ventanas(int k) {
    if (ventana_peligro > 0) {
        ventana_peligro -= k;
        if (ventana_peligro < 0) ventana_peligro = 0;
    }

    if (ventana_negacion > 0) {
        ventana_negacion -= k;
        if (ventana_negacion < 0) ventana_negacion = 0;
    }
}

static double multiplicador(double w) {
    if (ventana_negacion > 0) {
        return 0.0;
    }
    if (ventana_peligro > 0) {
        return w * 2.0;
    }
    return w; 
}

struct Evento { 
    string posibleSpoiler; 
    double peso;  
    int inicio;   
    int fin;      
};

static deque<Evento> cola_ventana; 
static int posicion_actual = 0;          
static const int HIST_N = TAM_VENTANA;


static void avanzar_posicion(int k) { 
    posicion_actual += k;
}

static bool hay_solapamiento(const Evento& a, const Evento& b) { 
    return !(a.fin < b.inicio || b.fin < a.inicio);
}

static void borrar_uno(vector<string>& v, const string& s) {
    auto it = find(v.begin(), v.end(), s);
    if (it != v.end()) {
        v.erase(it);
    }
}

static void limpiar_ventana() {
    int limit = posicion_actual - HIST_N;
    
    while (!cola_ventana.empty() && cola_ventana.front().fin <= limit) {
        cola_ventana.pop_front();
    }
}

static void aceptar_evento(string texto, double w, int k) { 
    limpiar_ventana();
    
    if (w <= 0.0001) {
        return; 
    }
    
    Evento neu;
    neu.posibleSpoiler = texto; 
    neu.peso = w;
    neu.inicio = posicion_actual - k + 1;
    neu.fin = posicion_actual;

    double best = -1.0;
    for (const auto& e : cola_ventana) {
        if (e.posibleSpoiler == texto || hay_solapamiento(e, neu)) {
            best = max(best, e.peso);
        }
    }
    
    if (best >= 0.0 && w <= best) {
        return;
    }

    for (auto it = cola_ventana.begin(); it != cola_ventana.end(); ) {
        if (it->posibleSpoiler == texto || hay_solapamiento(*it, neu)) {
            estado.puntuacion_total -= it->peso;
            borrar_uno(estado.palabras_ventana, it->posibleSpoiler);
            it = cola_ventana.erase(it);
        } else { 
            ++it; 
        }
    }
    
    estado.palabras_ventana.push_back(neu.posibleSpoiler);
    cola_ventana.push_back(neu);

    estado.procesar_evento(neu.posibleSpoiler, w);
    
}


%}

LETRA [a-zA-ZñÑ]
DIGITO [0-9]
ESP [ \t]+
WORD {LETRA}({LETRA}|{DIGITO})*
MAYUS [A-ZÁÉÍÓÚÑ0-9]
PALABRA_MAY {MAYUS}+

STOP_ART (el|la|los|las|un|una|unos|unas|lo|[Ee]l|[Ll]a)
STOP_PREP (de|del|al|en|a|por|para|con|sin|sobre|entre|hasta|desde|tras|ante|bajo|contra|durante|mediante)
STOP_CONJ (y|o|u|e|ni|pero|aunque|sino|porque|como|cuando)
STOP_PRON (me|te|se|nos|os|le|les|lo|la|los|las|mi|mis|tu|tus|su|sus|nuestro|nuestra|nuestros|nuestras)
STOP_DET (este|esta|estos|estas|ese|esa|esos|esas|aquel|aquella|aquellos|aquellas|cada|todo|toda|todos|todas|alguno|alguna|algunos|algunas)
STOP_AUX (he|has|ha|hemos|habeis|han|habia|habian|hubo|ser|soy|eres|es|somos|son|era|eran|fui|fue|fueron|estar|estoy|estas|esta|estamos|estan|estaba|estaban)
STOP_OTROS (que|como|muy|mas|menos|ya|aun|tambien|tampoco|solo|ahi|alli|aca|aqui)
STOPWORD ({STOP_ART}|{STOP_PREP}|{STOP_CONJ}|{STOP_PRON}|{STOP_DET}|{STOP_AUX}|{STOP_OTROS})

TITULO {PALABRA_MAY}([ \t]+({STOPWORD}[ \t]+)?{PALABRA_MAY})*

HDR_TIPO_LIBRO ^[Tt][Ii][Pp][Oo]{ESP}*:{ESP}*[Ll][Ii][Bb][Rr][Oo]{ESP}*\n
HDR_TIPO_PELI ^[Tt][Ii][Pp][Oo]{ESP}*:{ESP}*[Pp][Ee][Ll][Ii][Cc][Uu][Ll][Aa]{ESP}*\n
HDR_TIPO_SERIE ^[Tt][Ii][Pp][Oo]{ESP}*:{ESP}*[Ss][Ee][Rr][Ii][Ee]{ESP}*\n
HDR_TITULO ^[Tt][Ii][Tt][Uu][Ll][Oo]{ESP}*:{ESP}*.+\n
TIT_LINE ^[a-zA-ZñÑ][a-zA-ZñÑ \t]*\n

NIV_SIN ([Ss]in{ESP}+([Ss]poilers?|[Ss]poiler))
NIV_LEVE ([Ss]poiler{ESP}+([Mm]uy{ESP}+)?[Ll]eve)
NIV_MEDIO ([Ss]poiler{ESP}+([Mm]edio|[Mm]oderado))
NIV_GRAVE ([Ss]poiler{ESP}+([Mm]uy{ESP}+)?[Gg]rave)

/* Patrones para detectar aviso de spoiler (Ventana peligrosa)*/
AVISO_SPOILER (([Aa]tencion|[Aa]tención|[Aa]viso|[Aa]lerta){ESP}*[:\-]?\s*[Ss]poilers?)
ZONA_PELIGROSA (([Aa]l|[Ee]n){ESP}+el{ESP}+final|([Aa]l){ESP}+final|[Ff]inalmente|([Aa]l){ESP}+desenlace)

/* Patrones para detectar negacion (Ventana de negacion)*/
NEG_SIMPLE ([Nn]o|[Nn]unca|[Jj]amas|[Tt]ampoco|[Ff]also|[Mm]entira|[Ii]mposible)
NEG_COMPLEJA ([Nn]o{ESP}+[Ee]?s{ESP}+(verdad|cierto)|[Ee]s{ESP}+[Ff]also|[Ee]s{ESP}+[Mm]entira)

F_MUERE_PROTAG ([Mm]uere|[Mm]uerte){ESP}+([Ee]l{ESP}+|[Ll]a{ESP}+)?[Pp]rotagonista
F_ASESINO_ES [Ee]l{ESP}+[Aa]sesino{ESP}+es
F_VILLANO_ES [Ee]l{ESP}+[Vv]illano{ESP}+es
F_TODO_SUENO [Tt]odo{ESP}+era{ESP}+un{ESP}+sue[ñn]o
F_GIRO_FINAL [Gg]iro{ESP}+final
F_FINAL_INESP [Ff]inal{ESP}+inesperado
F_SE_REVELA [Ss]e{ESP}+revela{ESP}+verdad
F_PADRE_ES ((es|resulta{ESP}+ser){ESP}+(su{ESP}+)?padre|padre{ESP}+(verdader[oa]|real))
F_IDENTIDAD (su{ESP}+identidad|qui[eé]n{ESP}+(realmente{ESP}+)?es|resulta{ESP}+ser)
F_TRAIDOR_ES (resulta{ESP}+ser{ESP}+(el{ESP}+|la{ESP}+)?traidor(a)?|el{ESP}+traidor{ESP}+es)
F_LE_TIENDEN (le{ESP}+(tienden|tendieron){ESP}+una{ESP}+trampa|es{ESP}+una{ESP}+trampa)
F_DOBLE_AGENTE (doble{ESP}+agente|trabaja{ESP}+para{ESP}+(el|la){ESP}+enemig(o|a))

IND_MUERTE ([Mm]uer[a-z]*|[Ff]allec[a-z]*)
IND_MATAR ([Mm]at(ar|a|an|ado|aron|ando))
IND_ASES ([Aa]sesin[a-z]*)
IND_VILLANO ([Vv]illan[a-z]*)
IND_REVEL ([Rr]evel[a-z]*)
IND_TRAIC ([Tt]raic[a-z]*|[Tt]raidor[a-z]*)
IND_SUENO ([Ss]ue[ñn][a-z]*)
IND_SECRETO ([Ss]ecret[a-z]*)
IND_FINAL ([Ff]inal[a-z]*)
IND_SACRIF ([Ss]acrific[a-z]*)
IND_SALVA ([Ss]alv[a-z]*)
IND_ESCAPA ([Ee]scap[a-z]*)
IND_SOBREV ([Ss]obreviv[a-z]*)

IND_DEBIL_FINAL ([Ff]inal(mente)?|[Dd]esenlace)
IND_DEBIL_GIRO ([Gg]iro|[Tt]wist(s)?|[Pp]lot{ESP}+twist)
IND_DEBIL_SECRETO ([Ss]ecret(o|os)|[Mm]isteri(o|os)|[Cc]lave(s)?)
IND_DEBIL_IDENT ([Ii]dentidad|[Qq]ui[eé]n{ESP}+es)
IND_DEBIL_SPOILER ([Ss]poiler(s)?|[Dd]estrip(e|es)|[Ss]poilear)

PUNC [.,;:!?()"\[\]{}¡¿]

%x EST_CABECERA EST_CUERPO

%%

<INITIAL>{
    {HDR_TIPO_LIBRO} { 
        estado.tipo = TipoObra::LIBRO; 
        BEGIN(EST_CABECERA); 
    }
    
    {HDR_TIPO_PELI} { 
        estado.tipo = TipoObra::PELICULA; 
        BEGIN(EST_CABECERA); 
    }
    
    {HDR_TIPO_SERIE} { 
        estado.tipo = TipoObra::SERIE; 
        BEGIN(EST_CABECERA); 
    }
    
    .|\n { 
        yyless(0);
        BEGIN(EST_CUERPO);
    }
}

<EST_CABECERA>{
    {HDR_TITULO} {
        string t = valor_dos_puntos(string(yytext));
        if(!t.empty()){
            estado.titulo = t; 
            estado.tiene_titulo = true;
            estado.titulo_deducido = false;
        }
        BEGIN(EST_CUERPO);
    }
    
    ^{TITULO}\n {
        if (!estado.tiene_titulo) {
            string l = limpiar_salto_linea(string(yytext));
            if (!l.empty()) {
                estado.titulo = l;
                estado.tiene_titulo = true;
                estado.titulo_deducido = false;
            }
        }
        BEGIN(EST_CUERPO);
    }
    
    
    \n { 
        estado.tiene_titulo = false;
        BEGIN(EST_CUERPO); 
    }
    
    [ \t]+ ;

    . { 
        yyless(0);
        estado.tiene_titulo = false;
        BEGIN(EST_CUERPO); 
    }
}

<EST_CUERPO>{
    {AVISO_SPOILER} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        estado.etiqueta = Nivel::GRAVE; 
        aceptar_evento("aviso spoilers", PESO_AVISO_EXPLICITO, k); 
        activar_peligro(); 
        actualizar_ventanas(k); 
    }

    {NIV_SIN} { 
        estado.etiqueta = Nivel::SIN_SPOILERS; 
    }
    
    {NIV_LEVE} { 
        estado.etiqueta = Nivel::LEVE; 
    }
    
    {NIV_MEDIO} { 
        estado.etiqueta = Nivel::MEDIO; 
    }
    
    {NIV_GRAVE} { 
        estado.etiqueta = Nivel::GRAVE; 
    }
    
    {STOPWORD} { }

    {ZONA_PELIGROSA} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        activar_peligro(); 
        actualizar_ventanas(k); 
    }
    
    {NEG_SIMPLE}|{NEG_COMPLEJA} {
        int k = contar_tokens(yytext, yyleng);
        avanzar_posicion(k);
        actualizar_ventanas(k);
        activar_negacion(); 
    }

    {F_MUERE_PROTAG} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("muere protagonista", multiplicador(PESO_FR_MUERE_PROTAG), k); 
        actualizar_ventanas(k); 
    }
    
    {F_ASESINO_ES} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("el asesino es", multiplicador(PESO_FR_ASESINO_ID), k); 
        actualizar_ventanas(k); 
    }
    
    {F_VILLANO_ES} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("el villano es", multiplicador(PESO_FR_VILLANO_ID), k); 
        actualizar_ventanas(k); 
    }
    
    {F_TODO_SUENO} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("todo era un sueno", multiplicador(PESO_FR_TODO_SUENO), k); 
        actualizar_ventanas(k); 
    }
    
    {F_GIRO_FINAL} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("giro final", multiplicador(PESO_FR_GIRO_FINAL), k); 
        actualizar_ventanas(k); 
    }
    
    {F_FINAL_INESP} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("final inesperado", multiplicador(PESO_FR_FINAL_INESP), k); 
        actualizar_ventanas(k); 
    }
    
    {F_SE_REVELA} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("se revela verdad", multiplicador(PESO_FR_REVELACION), k); 
        actualizar_ventanas(k); 
    }
    
    {F_PADRE_ES} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("es su padre", multiplicador(PESO_FR_PADRE_ES), k); 
        actualizar_ventanas(k); 
    }
    
    {F_IDENTIDAD} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("identidad revelada", multiplicador(PESO_FR_REVELACION), k); 
        actualizar_ventanas(k); 
    }
    
    {F_TRAIDOR_ES} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("traidor es", multiplicador(PESO_FR_TRAIDOR_ES), k); 
        actualizar_ventanas(k); 
    }
    
    {F_LE_TIENDEN} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("es una trampa", multiplicador(PESO_FR_TRAMPA), k); 
        actualizar_ventanas(k); 
    }
    
    {F_DOBLE_AGENTE} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("doble agente", multiplicador(PESO_FR_TRAMPA), k); 
        actualizar_ventanas(k); 
    }

    {IND_MUERTE} { 
        avanzar_posicion(1); 
        aceptar_evento("muerte", multiplicador(PESO_KW_VIOLENCIA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_MATAR} { 
        avanzar_posicion(1); 
        aceptar_evento("matar", multiplicador(PESO_KW_VIOLENCIA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_ASES}/{ESP}{MAYUS} { 
        avanzar_posicion(1); 
        aceptar_evento("asesino_id", multiplicador(PESO_FR_ASESINO_ID), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_ASES} { 
        avanzar_posicion(1); 
        aceptar_evento("asesino", multiplicador(PESO_KW_VIOLENCIA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_VILLANO} { 
        avanzar_posicion(1); 
        aceptar_evento("villano", multiplicador(PESO_KW_TRAMA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_SACRIF} { 
        avanzar_posicion(1); 
        aceptar_evento("sacrificio", multiplicador(PESO_KW_TRAMA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_SUENO} { 
        avanzar_posicion(1); 
        aceptar_evento("sueno", multiplicador(PESO_KW_TRAMA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_REVEL} { 
        avanzar_posicion(1); 
        aceptar_evento("revelacion", multiplicador(PESO_KW_ACCION), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_TRAIC} { 
        avanzar_posicion(1); 
        aceptar_evento("traicion", multiplicador(PESO_KW_ACCION), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_SECRETO} { 
        avanzar_posicion(1); 
        aceptar_evento("secreto", multiplicador(PESO_KW_ACCION), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_SALVA} { 
        avanzar_posicion(1); 
        aceptar_evento("salva", multiplicador(PESO_KW_ACCION), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_ESCAPA} { 
        avanzar_posicion(1); 
        aceptar_evento("escapa", multiplicador(PESO_KW_ACCION), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_SOBREV} { 
        avanzar_posicion(1); 
        aceptar_evento("sobrevive", multiplicador(PESO_KW_ACCION), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_DEBIL_FINAL} { 
        avanzar_posicion(1); 
        aceptar_evento("hint_final", multiplicador(PESO_KW_PISTA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_DEBIL_GIRO} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("hint_giro", multiplicador(PESO_KW_PISTA), k); 
        actualizar_ventanas(k); 
    }
    
    {IND_DEBIL_SECRETO} { 
        avanzar_posicion(1); 
        aceptar_evento("hint_secreto", multiplicador(PESO_KW_PISTA), 1); 
        actualizar_ventanas(1); 
    }
    
    {IND_DEBIL_IDENT} { 
        int k = contar_tokens(yytext, yyleng); 
        avanzar_posicion(k); 
        aceptar_evento("hint_identidad", multiplicador(PESO_KW_PISTA), k); 
        actualizar_ventanas(k); 
    }
    
    {IND_DEBIL_SPOILER} { 
        avanzar_posicion(1); 
        aceptar_evento("aviso_spoiler", multiplicador(PESO_KW_AVISO_DEBIL), 1); 
        actualizar_ventanas(1); 
    }

    {WORD} { 
        avanzar_posicion(1); 
        double mult = multiplicador(1.0); 
        if(mult > 0){
            analizador.procesar_palabra(yytext, yyleng, mult, estado); 
        }
        actualizar_ventanas(1); 
    }

    {PUNC}+ { }

    [ \t\r]+ { }
    
    \n { }
    
    . { }
}

<<EOF>> { return 0; }

%%


void reset_lex() {
    ventana_peligro = 0;
    ventana_negacion = 0;
    cola_ventana.clear();
    posicion_actual = 0;
    estado = EstadoResena();
    BEGIN(INITIAL);
}
