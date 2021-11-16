global T_media
global VT
global VT_nuevo#Vector temperatura para ir almacenando nuevos valores
global estado #Si la pava esta prendida o apagada
global T_real #La temperatura del agua
T_real=15;
load tabla_pendientes
global pendientes_t = tabla_pendientes
global valores_k
load valores_k

function estado = on_off(temperatura_seteada)
    DT = calculo_DT();
    T = calculo_t_media();
    
    if T+DT >= temperatura_seteada
        estado=0;
    else
        estado=1;
    end
end

function DT = calculo_DT()
    global pendientes_t
    pendiente = calculo_pendiente();
    x=1;
    while(pendiente < pendientes_t(x, 1))
        x++;
        if x > length(pendientes_t(:, 1))
            DT=pendientes_t(x-1, 2);
            return
        end
    end
    DT = pendientes_t(x, 2);
end

function pendiente = calculo_pendiente()
    global VT;
    X = linspace(0, 1, 36);#Intervalo de tiempo de un segundo
    Y = VT;#Vector temperaturas medidas en un segundo fraccionadas en 12 mediciones

    #Calculo valores para pendiente de regresion lineal
    n = length(X);
    x = sum(X);
    y = sum(Y);
    xy = sum(X .* Y);
    xx = sum(X .^ 2);
    xx2 = (sum(X))^2;
    med_x = (mean(X));
    med_y = (mean(Y));

    pendiente = (n*xy - x*y) / (n*xx - xx2);
end

function t_media = calculo_t_media()
    global VT
    t_media = mean(VT);
end

function calculo_VT(t_instantanea)
    global VT_nuevo;
    VT_nuevo(end+1) = t_instantanea;
    
    if length(VT_nuevo) > 35
        global VT
        VT = VT_nuevo;
        VT_nuevo = [];
    end
end

function resultado = heun(f, x_0, y_0, X, cant_pasos=1)
    h = abs((x_0-X) / cant_pasos);
    x = x_0;
    y = y_0;
    
    while x < X
        x1 = x+h;
        y1p = y + f(x, y)*h;
        y1 = y + h*(f(x, y) + f(x1, y1p)) / 2;
        x=x1;
        y=y1;
    end
    resultado = y;
end    

function sonda(k)
    global T_real;
    global estado;

    if estado==1
        f = @(T) k*(T-400);
        T_real = heun(f, 0, T_real, 1/36);#El tempo va de 0 a 1/36, no me interesa el tiempo real, solo el paso que da
    else
        return
    end
end

function registro_simulacion = simulador(cantidad_agua, T_seteada, T_inicial=15, max_t=1024)
    #Primero determino valor de k para simular nivel de agua
    if cantidad_agua < 0.5
        printf("Se cargo menos agua de la permitida por la pava, cargar mas\n")
        return
    elseif cantidad_agua > 1.5
        printf("Se cargo agua de mas, cargar menos y reintentar\n")
        return
    end
    load valores_k;
    x=1;
    while valores_k(x, 1) < cantidad_agua
        x++;
    end
    k = valores_k(x, 2);
    #Chequeo que la temperatura este en el rango optimo
    T=T_seteada;
    if or(T > 100, T < 25)
        printf("Setear temperatura entre 25 y 100 grados\n")
        return
    end
    
    #Preparo parametros para simulacion
    global T_real
    T_real = T_inicial;
    global estado
    registro = [];
    
    #Inicializo VT
    global VT
    global VT_aux
    VT=0;
    VT_aux=0;
    for x=[1:36]
        sonda(k)
        calculo_VT(T_real)
    end
    
    #Prendo la pava
    estado=1;
    t=0;
    while(estado==1)
        for x=[1:36]
            sonda(k)
            calculo_VT(T_real)
        end
        estado=on_off(T);
        t++;
        if(t>max_t)
            printf("Se supera max_iter\n")
            return
        end
        
        #Guardo resultados en registro
        registro(t, 1) = t;
        registro(t, 2) = T_real;
    end
    registro_simulacion = registro;
    plot(registro(:, 1), registro(:, 2), 'b', 'LineWidth', 2)
    grid on
    axis([0, t+12, 0, 100])
    title('Variacion de temperatura respecto al tiempo')
    xlabel('Tiempo (s)')
    xlabel('Temperatura')
end