import requests

def obtener_gini_argentina():
    url = "https://api.worldbank.org/v2/en/country/all/indicator/SI.POV.GINI?format=json&date=2011:2020&per_page=32500&page=1&country=%22Argentina%22"
    
    try:
        respuesta = requests.get(url)
        respuesta.raise_for_status() 
        
        datos = respuesta.json()
        lista_datos = datos[1]
        
        for registro in lista_datos:
            if registro['country']['id'] == 'AR' and registro['value'] is not None:
                # SOLO devolvemos el número, sin imprimir textos acá adentro
                return float(registro['value'])
                
        return None

    except requests.exceptions.RequestException:
        return None

# El bloque de abajo SOLO se ejecuta si llamamos a Python a mano desde la terminal
# Si C importa este archivo, esto se ignora.
if __name__ == "__main__":
    valor = obtener_gini_argentina()
    if valor:
        print(f"Python (Test manual): Índice GINI encontrado: {valor}")
    else:
        print("Python (Test manual): Error al obtener el dato.")