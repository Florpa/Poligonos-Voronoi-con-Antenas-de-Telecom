
1- Creo la columna geom en la tabla donde estan los datos de telecom
alter table telecom.dispositivos_1111 add column geom geometry 
2- Construyo la Geometria y actualizo ese campo
update set telecom.dispositivos_1111 set geom = (ST_SetSRID(ST_MakePoint(uli_sitiorm_longitud , uli_sitiorm_latitud),4326))
where geom is null
3- Ejecuto la siguiente consulta

with 
antenas as (-- tabla Telecom con la columna geom construida previamente
    select st_transform(geom,5347) as geom, date, sum(n_lineas)*3.3 AS lineas,hora 
    from telecom.dispositivos_1111  a -- nombre de la tabla con los datos de telecom.
    where  hora= '0:30'  and date ='2020-10-20' 
    --El where es opcional, en caso que no se rellene lo hara para todos los dias/horas deseadas
    group by  geom, date,hora 
	order by hora),
calendario as( --calendario
    select pk_fecha,fecha,semana,dia_semana,dia,
            mes,dia_semana_nombre,feriado 
    from aux.calendario_2020),
voro as (-- construyo los voronois a partir de los geom de las antenas
    select x.geom, b.lineas as moviles, date, hora 
    from (select (ST_DUMP(ST_VoronoiPolygons(ST_Collect(geom)))).geom as geom 
            from antenas)x 
    inner join antenas b on st_within (b.geom, x.geom) ),
caba as ( --la tabla radios Caba esta en la ddbb Telecom.
    select st_transform(st_union(geom),5347) as geom 
    from aux.radios_caba),
vorointer as (-- corto a los poligonos de Voronoi con el limite de caba que construi a partir de los radios
        select st_intersection(b.geom,a.geom) as geom, moviles, date, 
            hora,st_area(st_intersection(b.geom,a.geom)) as tarea  
        from voro a 
        inner join caba b on st_intersects(a.geom, b.geom)), 
fraccion as (--- aca traigo la grilla que voy a usar, en este caso la de 150, en caso de querer usar otra unidad espacial, aca es donde debe modificarse :D
     select st_transform(geom,5347) as geom,id as fraccion 
     from  aux.cuadrado_150),
vorofrac as ( -- interseco los poligonos de voronoi con las grillas
    select ST_Intersection(a.geom, b.geom) as geom, 
            a.fraccion, moviles, tarea,date, hora,
            st_area(ST_Intersection(a.geom, b.geom)) as  farea 
    from fraccion a 
    inner join vorointer  b on st_intersects(a.geom, b.geom)) ,
combi as ( -- calculo la superficie ocupada de un poligono dentro de otro y sus superficies
    select  GEOM, FRACCION, MOVILES, tarea, 
            ((farea *100)/tarea) as porarea, 
            ((farea*moviles)/tarea) as fantena,date, hora  
    from vorofrac),
presalida as (-- uno las geometrias de las grillas y sumo la cantidad de dispositivos que hay en cada poligono
    select st_union(geom) as geom, fraccion, round(sum(fantena)) as moviles, date, hora 
    from combi 
    group by fraccion,date, hora),
salida as (
    select  st_transform(geom,4326) as geom,
            fraccion,moviles,moviles/(st_area(geom)/1000000) as densidad,date,hora 
    from presalida),
insertar as (
   
            select fraccion,b.fecha,hora,moviles,b.semana 
            from salida a join calendario b on a.date=b.fecha)

select * from insertar