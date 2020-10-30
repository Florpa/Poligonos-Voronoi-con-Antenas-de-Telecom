# borra

import psycopg2
import sys
import datetime


# Abre la coneccion y la request
connection = psycopg2.connect(user="postgres@godatos",
                              password="datoscimmit1234$",
                              host="godatos.postgres.database.azure.com",
                              port="5432",
                              database="telecom")

cur = connection.cursor()
print("conectado")
print(datetime.datetime.today())
#000 Agrego la columna Geom
cur.execute("alter table public.dispositivos_caba add column if not exists geom geometry (point,4326)")
connection.commit()

#001 Index a las columnas 
print ('Indexando las columnas')
cur.execute("create index on public.dispositivos_caba (date);create index on public.dispositivos_caba (hora); create index on public.dispositivos_caba using gist(geom);")
print ('Termine de Indexar las columnas')
connection.commit()

#002 Construyo la geometria de las antenas  
print ('Construyendo el campo geom  a partir de los lat/long')
cur.execute("update public.dispositivos_caba  set geom = (ST_SetSRID(ST_MakePoint(long, lat),4326))where geom is null")
connection.commit()
print ('Termine de actualizar el campo geom')

#003 Consulta  de fechas y horas
cur.execute("SELECT date FROM public.dispositivos_caba where date >  (select max(fecha )from datos.dispositivos_por_grilla)GROUP BY date order by date")
fechas = cur.fetchall()
if len(fechas) == 0:
    fechas = [['2020-03-08']] #En el caso que se realice por primera vez, es necesario modificar esta fecha para poder realizar el primer dia
cur.execute(
    "select distinct(HORA::time) FROM public.dispositivos_caba group by hora::time order by 1 asc")
horas = cur.fetchall()

#004 Iteracion por dia y hora. Construccion de voronois y pasaje a las grillas. Insert de resultados  
for fecha in fechas:
    fecha = (str(fecha[0]))
    print(fecha,datetime.datetime.today())
    for hora in horas:
        hora = (str(hora[0]))
        cur.execute("with antenas as (select st_transform(geom,5347) as geom, date as day, sum(n_lineas)*3.3 AS lineas,hora from public.dispositivos_caba a where  hora::time = '"+hora+"' and date = '"+fecha+"' group by  geom, date,hora order by hora),calendario as( select pk_fecha,fecha,semana,dia_semana,dia,mes,dia_semana_nombre,feriado from aux.calendario_2020),voro as (select x.geom, b.lineas as moviles, day, hora from (SELECT (ST_DUMP(ST_VoronoiPolygons(ST_Collect(geom)))).geom as geom from antenas)x inner join antenas b on st_within (b.geom, x.geom) ),caba as ( Select st_transform(st_union(geom),5347) as geom from aux.radios_caba),vorointer as (select st_intersection(b.geom,a.geom) as geom, moviles, day, hora,st_area(st_intersection(b.geom,a.geom)) as tarea  from voro a inner join caba b on st_intersects(a.geom, b.geom)), fraccion as (select st_transform(geom,5347) as geom,id as fraccion from  aux.cuadrado_150),vorofrac as (select ST_Intersection(a.geom, b.geom) as geom, a.fraccion, moviles, tarea,day, hora, st_area(ST_Intersection(a.geom, b.geom)) as  farea from fraccion a inner join vorointer  b on st_intersects(a.geom, b.geom)) ,combi as ( select  GEOM, FRACCION, MOVILES, tarea, ((farea *100)/tarea) as porarea, ((farea*moviles)/tarea) as fantena,day, hora  from vorofrac),presalida as (select st_union(geom) as geom, fraccion, round(sum(fantena)) as moviles, day, hora from combi group by fraccion,day, hora),salida as (select st_transform(geom,4326) as geom,fraccion,moviles,moviles/(st_area(geom)/1000000) as densidad,day,hora from presalida),insertar as (insert into datos.dispositivos_por_grilla (fraccion, fecha, hora, moviles, semana)select fraccion,b.fecha,hora,moviles,b.semana from salida a join calendario b on a.day=b.fecha)select count(*) from datos.dispositivos_por_grilla")
        connection.commit()
    print('Finalizado:', fecha)

print(datetime.datetime.today())

cur.close()
connection.close()
