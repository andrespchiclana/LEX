#!/usr/bin/env python3
import subprocess
import os
import time
import pty

EJECUTABLE = './spoilers'
LOG_FILE = "resultados_tests.txt"

def escribir_log(f, nombre_prueba, entrada_mostrada, salida_programa):
    f.write(f"TEST: {nombre_prueba}\n")
    f.write("-" * 50 + "\n")
    f.write("DATOS DE PRUEBA:\n")
    f.write(entrada_mostrada.rstrip() + "\n") # rstrip para evitar doble salto de linea final
    f.write("-" * 50 + "\n")
    f.write("SALIDA DEL PROGRAMA:\n")
    f.write(salida_programa.strip() + "\n")
    f.write("=" * 50 + "\n\n\n")

def test_cabecera(nombre, input_str, f):
    print(f"Ejecutando: {nombre}...", end=" ")
    try:
        p = subprocess.Popen([EJECUTABLE], 
                             stdin=subprocess.PIPE, 
                             stdout=subprocess.PIPE, 
                             stderr=subprocess.STDOUT, 
                             text=True)
        salida, _ = p.communicate(input=input_str)
        
        escribir_log(f, nombre, input_str, salida)
        print("OK")
    except Exception as e:
        print(f"ERROR: {e}")

def test_interactivo(nombre, pasos_lista, f):
    print(f"Ejecutando: {nombre} ...", end=" ")
    
    master, slave = pty.openpty()
    p = subprocess.Popen([EJECUTABLE], 
                         stdin=slave, 
                         stdout=slave, 
                         stderr=slave, 
                         close_fds=True, 
                         text=True, 
                         bufsize=0)
    os.close(slave)
    
    entrada_readable = ""
    
    for paso in pasos_lista:
        time.sleep(0.15)
        os.write(master, paso.encode())
        
        if paso == "\x04":
            entrada_readable += "[CTRL+D]"
        else:
            entrada_readable += paso

    salida_bytes = b""
    while True:
        try:
            chunk = os.read(master, 1024)
            if not chunk: break
            salida_bytes += chunk
        except: break
        if p.poll() is not None: break
    os.close(master)
    
    salida_str = salida_bytes.decode(errors='ignore').replace('\r\n', '\n')
    escribir_log(f, nombre, entrada_readable, salida_str)
    print("OK")

def main():
    if not os.path.exists(EJECUTABLE):
        print("Falta el ejecutable.")
        return

    f = open(LOG_FILE, "w", encoding="utf-8")
    
    # 1. Prueba Base (Pipe)
    test_cabecera("1. Modo Cabecera (El Rey Leon)", "TIPO: PELICULA\nTITULO: El Rey Leon\nMuere Mufasa.\n", f)

    # 2. Prueba Interactiva
    pasos = ["2\n", "El Rey Leon\n", "Muere Mufasa.\n", "\x04", "n\n"]
    test_interactivo("2. Modo Interactivo (El Rey Leon)", pasos, f)

    # 3. Stopwords
    test_cabecera("3. Solo Stopwords", "TIPO: LIBRO\nTITULO: Test\nEl la los un una.\n", f)

    # 4. Contexto
    test_cabecera("4.1 Sin ventana", "TIPO: LIBRO\nTITULO: Test\nmuere el protagonista.\n", f)
    test_cabecera("4.2 Ventana peligrosa", "TIPO: LIBRO\nTITULO: Test\nAl final muere el protagonista.\n", f)
    test_cabecera("4.3 Ventana de negacion", "TIPO: LIBRO\nTITULO: Test\nNo muere el protagonista.\n", f)
    
    # 5. Base de Datos
    test_cabecera("5.1 BD General", "TIPO: PELICULA\nTITULO: X\nEl villano mata al maestro.\n", f)
    test_cabecera("5.2 BD Especifica (Harry Potter)", "TIPO: PELICULA\nTITULO: Harry Potter\nSnape mata a Dumbledore.\n", f)

    # 6. Deduccion
    test_cabecera("6. Deduccion de Obra", "TIPO: PELICULA\nTITULO: \nNeo y Morfeo entran en la Matrix.\n", f)
    
    # 7. Etiquetas
    test_cabecera("7.1 Etiqueta Sin Spoilers", "TIPO: PELICULA\nTITULO: Test\nSin Spoilers\nmuere todo el mundo.\n", f)
    test_cabecera("7.2 Etiqueta Spoiler Grave", "TIPO: PELICULA\nTITULO: Test\nSpoiler Grave\nHola.\n", f)

    f.close()
    print(f"Hecho. Resultados en {LOG_FILE}")

if __name__ == "__main__":
    main()