# Compilador y opciones
CXX      := g++
CXXFLAGS := -std=c++17 -Wall -Wextra -Iinclude

# Flex
FLEX       := flex
LEX_SOURCE := src/spoilers.l
LEX_OUTPUT := build/lex.yy.c

# Ejecutable final
TARGET := spoilers

# Objetos
OBJ := \
    build/main.o \
    build/estado_resena.o \
    build/spoiler_db.o \
    build/spoilers.o \
    build/lex.yy.o


.PHONY: all clean run

all: build $(TARGET)

# Carpeta donde dejamos todo lo compilado
build:
	mkdir -p build

# Enlazar todo
$(TARGET): $(OBJ)
	$(CXX) $(CXXFLAGS) $^ -o $@

# Generar lex.yy.c a partir de spoilers.l
$(LEX_OUTPUT): $(LEX_SOURCE) | build
	$(FLEX) -o $@ $<

# Compilar el lex.yy.c
build/lex.yy.o: $(LEX_OUTPUT)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Regla genérica para los .cpp normales
build/%.o: src/%.cpp | build
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Limpiar compilados
clean:
	rm -rf build $(TARGET)

# Atajo para ejecutar
run: all
	./$(TARGET)
