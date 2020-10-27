
with 
antenas as (-- tabla Telecom con la comlumna geom construida
    select st_transform(geom,5347) as geom, day, sum(cant_lineas)*3.3 AS lineas,hora 
    from telecom.dispositivos_0711 a
    where  hora::time =  and day = 
    --El where es opcional, en caso que no se rellene lo hara para todos los dias/horas deseadas
    group by  geom, day,hora order by hora),
calendario as( --calendario
    select pk_fecha,fecha,semana,dia_semana,dia,
            mes,dia_semana_nombre,feriado 
    from telecom.calendario_2020),
voro as (-- construyo los voronois a partir de los geom de las antenas
    select x.geom, b.lineas as moviles, day, hora 
    from (select (ST_DUMP(ST_VoronoiPolygons(ST_Collect(geom)))).geom as geom 
            from antenas)x 
    inner join antenas b on st_within (b.geom, x.geom) ),
caba as ( --la tabla radios Caba esta en la ddbb Telecom.
    select st_transform(st_union(geom),5347) as geom 
    from flor.radios_caba),
vorointer as (-- corto a los poligonos de Voronoi con el limite de caba que construi a partir de los radios
        select st_intersection(b.geom,a.geom) as geom, moviles, day, 
            hora,st_area(st_intersection(b.geom,a.geom)) as tarea  
        from voro a 
        inner join caba b on st_intersects(a.geom, b.geom)), 
fraccion as (--- aca traigo la grilla que voy a usar, en este caso la de 150, en caso de querer usar otra unidad espacial, aca es donde debe modificarse :D
     select st_transform(geom,5347) as geom,id as fraccion 
     from  general.cuadrado_150),
vorofrac as ( -- interseco los poligonos de voronoi con las grillas
    select ST_Intersection(a.geom, b.geom) as geom, 
            a.fraccion, moviles, tarea,day, hora,
            st_area(ST_Intersection(a.geom, b.geom)) as  farea 
    from fraccion a 
    inner join vorointer  b on st_intersects(a.geom, b.geom)) ,
combi as ( -- calculo la superficie ocupada de un poligono dentro de otro y sus superficies
    select  GEOM, FRACCION, MOVILES, tarea, 
            ((farea *100)/tarea) as porarea, 
            ((farea*moviles)/tarea) as fantena,day, hora  
    from vorofrac),
presalida as (-- uno las geometrias de las grillas y sumo la cantidad de dispositivos que hay en cada poligono
    select st_union(geom) as geom, fraccion, round(sum(fantena)) as moviles, day, hora 
    from combi 
    group by fraccion,day, hora),
 salida as (--reproyecto el geom y traigo los campos que me interesa conservar
    select st_transform(geom,4326) as geom,fraccion,
        moviles,day,hora 
    from presalida)

    select * from salida 

   