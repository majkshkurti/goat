--Forked FROM https://gist.github.com/dbauszus/1ba78db34da0140e02c03d99303812ea

CREATE OR REPLACE FUNCTION public.hexagrid(_height numeric)
 RETURNS void 
 LANGUAGE plpgsql
AS $function$

DECLARE
_table  text  := 'grid_' || _height::text;   
_curs   CURSor For SELECT st_transform(geom,3857) FROM study_area_union;
_srid   integer  := 3857;
_width  numeric  := _height * 0.866;
_geom   GEOMETRY;
_hx     GEOMETRY := ST_GeomFROMText(
                        ForMAT('POLYGON((0 0, %s %s, %s %s, %s %s, %s %s, %s %s, 0 0))',
                          (_width *  0.5), (_height * 0.25),
                          (_width *  0.5), (_height * 0.75),
                                       0 ,  _height,
                          (_width * -0.5), (_height * 0.75),
                          (_width * -0.5), (_height * 0.25)
                        ), _srid);

BEGIN
   
  CREATE TEMP TABLE hx_tmp (geom GEOMETRY(POLYGON));

  OPEN _curs;
  LOOP
    FETCH
    _curs INTO _geom;
    EXIT WHEN NOT FOUND;

    INSERT INTO hx_tmp
      SELECT
        ST_Translate(_hx, x_series, y_series)::GEOMETRY(POLYGON) geom
      FROM
        generate_series(
          (st_xmin(_geom) / _width)::INTEGER * _width - _width,
          (st_xmax(_geom) / _width)::INTEGER * _width + _width,
          _width) x_series,
        generate_series(
          (st_ymin(_geom) / (_height * 1.5))::INTEGER * (_height * 1.5) - _height,
          (st_ymax(_geom) / (_height * 1.5))::INTEGER * (_height * 1.5) + _height,
          _height * 1.5) y_series
      WHERE
        ST_Intersects(ST_Translate(_hx, x_series, y_series)::GEOMETRY(POLYGON), _geom);

    INSERT INTO hx_tmp
      SELECT ST_Translate(_hx, x_series, y_series)::GEOMETRY(POLYGON) geom
      FROM
        generate_series(
          (st_xmin(_geom) / _width)::INTEGER * _width - (_width * 1.5),
          (st_xmax(_geom) / _width)::INTEGER * _width + _width,
          _width) x_series,
        generate_series(
          (st_ymin(_geom) / (_height * 1.5))::INTEGER * (_height * 1.5) - (_height * 1.75),
          (st_ymax(_geom) / (_height * 1.5))::INTEGER * (_height * 1.5) + _height,
          _height * 1.5) y_series
      WHERE
        ST_Intersects(ST_Translate(_hx, x_series, y_series)::GEOMETRY(POLYGON), _geom);

  END LOOP;
  CLOSE _curs;

  CREATE INDEX sidx_hx_tmp_geom ON hx_tmp USING GIST (geom);
  EXECUTE 'DROP TABLE IF EXISTS '|| _table;
  EXECUTE 'CREATE TABLE '|| _table ||' (geom GEOMETRY(POLYGON, '|| _srid ||'))';
  EXECUTE 'INSERT INTO '|| _table ||' SELECT * FROM hx_tmp GROUP BY geom';
  EXECUTE 'CREATE INDEX sidx_'|| _table ||'_geom ON '|| _table ||' USING GIST (geom)';
  EXECUTE 'ALTER TABLE ' ||_table||' 
       ALTER COLUMN geom TYPE geometry(Polygon,4326) 
           USING ST_Transform(geom,4326)';
  DROP TABLE IF EXISTS hx_tmp;
  
END
$function$



