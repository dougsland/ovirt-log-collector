--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--
CREATE TABLE timezone_temp (
    zone VARCHAR(40),
    area VARCHAR(40)
);

-- Values defined in ovirt-engine project:
-- backend/manager/modules/compat/src/main/java/org/ovirt/engine/core/compat/WindowsJavaTimezoneMapping.java

INSERT INTO timezone_temp VALUES
    ('AUS Central Standard Time', 'Australia/Darwin'),
    ('AUS Eastern Standard Time', 'Australia/Sydney'),
    ('Afghanistan Standard Time', 'Asia/Kabul'),
    ('Alaskan Standard Time', 'America/Anchorage'),
    ('Arab Standard Time', 'Asia/Riyadh'),
    ('Arabian Standard Time', 'Asia/Dubai'),
    ('Arabic Standard Time', 'Asia/Baghdad'),
    ('Argentina Standard Time', 'America/Buenos_Aires'),
    ('Armenian Standard Time', 'Asia/Yerevan'),
    ('Atlantic Standard Time', 'America/Halifax'),
    ('Azerbaijan Standard Time', 'Asia/Baku'),
    ('Azores Standard Time', 'Atlantic/Azores'),
    ('Canada Central Standard Time', 'America/Regina'),
    ('Cape Verde Standard Time', 'Atlantic/Cape_Verde'),
    ('Caucasus Standard Time', 'Asia/Yerevan'),
    ('Cen. Australia Standard Time', 'Australia/Adelaide'),
    ('Central America Standard Time', 'America/Guatemala'),
    ('Central Asia Standard Time', 'Asia/Dhaka'),
    ('Central Brazilian Standard Time', 'America/Manaus'),
    ('Central Europe Standard Time', 'Europe/Budapest'),
    ('Central European Standard Time', 'Europe/Warsaw'),
    ('Central Pacific Standard Time', 'Pacific/Guadalcanal'),
    ('Central Standard Time', 'America/Chicago'),
    ('Central Standard Time', 'America/Mexico_City'),
    ('China Standard Time', 'Asia/Shanghai'),
    ('Central Standard Time (Mexico)', 'America/Mexico_City'),
    ('Dateline Standard Time', 'Etc/GMT+12'),
    ('E. Africa Standard Time', 'Africa/Nairobi'),
    ('E. Australia Standard Time', 'Australia/Brisbane'),
    ('E. Europe Standard Time', 'Europe/Minsk'),
    ('E. South America Standard Time', 'America/Sao_Paulo'),
    ('Eastern Standard Time', 'America/New_York'),
    ('Egypt Standard Time', 'Africa/Cairo'),
    ('Ekaterinburg Standard Time', 'Asia/Yekaterinburg'),
    ('FLE Standard Time', 'Europe/Kiev'),
    ('Fiji Standard Time', 'Pacific/Fiji'),
    ('GMT Standard Time', 'Europe/London'),
    ('GTB Standard Time', 'Europe/Istanbul'),
    ('Georgian Standard Time', 'Asia/Tbilisi'),
    ('Greenland Standard Time', 'America/Godthab'),
    ('Greenwich Standard Time', 'Africa/Reykjavik'),
    ('Hawaiian Standard Time', 'Pacific/Honolulu'),
    ('India Standard Time', 'Asia/Calcutta'),
    ('Iran Standard Time', 'Asia/Tehran'),
    ('Israel Standard Time', 'Asia/Jerusalem'),
    ('Jordan Standard Time', 'Asia/Amman'),
    ('Korea Standard Time', 'Asia/Seoul'),
    ('Mauritius Standard Time', 'Indian/Mauritius'),
    ('Mexico Standard Time', 'America/Mexico_City'),
    ('Mexico Standard Time', 'America/Chihuahua'),
    ('Mid-Atlantic Standard Time', 'Atlantic/South_Georgia'),
    ('Middle East Standard Time', 'Asia/Beirut'),
    ('Mid-Atlantic Standard Time', 'Atlantic/South_Georgia'),
    ('Middle East Standard Time', 'Asia/Beirut'),
    ('Montevideo Standard Time', 'America/Montevideo'),
    ('Morocco Standard Time', 'Africa/Casablanca'),
    ('Mountain Standard Time', 'America/Denver'),
    ('Mountain Standard Time', 'America/Chihuahua'),
    ('Myanmar Standard Time', 'Asia/Rangoon'),
    ('N. Central Asia Standard Time', 'Asia/Novosibirsk'),
    ('Namibia Standard Time', 'Africa/Windhoek'),
    ('Nepal Standard Time', 'Asia/Katmandu'),
    ('New Zealand Standard Time', 'Pacific/Auckland'),
    ('Newfoundland Standard Time', 'America/St_Johns'),
    ('North Asia East Standard Time', 'Asia/Irkutsk'),
    ('North Asia Standard Time', 'Asia/Krasnoyarsk'),
    ('Pacific SA Standard Time', 'America/Santiago'),
    ('Pacific Standard Time', 'America/Los_Angeles'),
    ('Pacific Standard Time', 'America/Tijuana'),
    ('Pakistan Standard Time', 'Asia/Karachi'),
    ('Romance Standard Time', 'Europe/Paris'),
    ('Russian Standard Time', 'Europe/Moscow'),
    ('SA Eastern Standard Time', 'America/Buenos_Aires'),
    ('SA Pacific Standard Time', 'America/Bogota'),
    ('SA Western Standard Time', 'America/La_Paz'),
    ('SE Asia Standard Time', 'Asia/Bangkok'),
    ('Samoa Standard Time', 'Pacific/Apia'),
    ('Singapore Standard Time', 'Asia/Singapore'),
    ('South Africa Standard Time', 'Africa/Johannesburg'),
    ('Sri Lanka Standard Time', 'Asia/Colombo'),
    ('Taipei Standard Time', 'Asia/Taipei'),
    ('Tasmania Standard Time', 'Australia/Hobart'),
    ('Tokyo Standard Time', 'Asia/Tokyo'),
    ('Tonga Standard Time', 'Pacific/Tongatapu'),
    ('US Eastern Standard Time', 'America/New_York'),
    ('US Mountain Standard Time', 'America/Phoenix'),
    ('Venezuela Standard Time', 'America/Caracas'),
    ('Vladivostok Standard Time', 'Asia/Vladivostok'),
    ('W. Australia Standard Time', 'Australia/Perth'),
    ('W. Central Africa Standard Time', 'Africa/Lagos'),
    ('W. Europe Standard Time', 'Europe/Berlin'),
    ('West Asia Standard Time', 'Asia/Tashkent'),
    ('West Pacific Standard Time', 'Pacific/Port_Moresby'),
    ('Yakutsk Standard Time', 'Asia/Yakutsk')
;

-- Values defined in ovirt-engine project:
-- packaging/conf/osinfo-defaults.properties
--
-- 1 - WindowsXP
-- 3 - Windows2003
-- 4 - Windows2008
-- 10 - Windows2003x64
-- 11 - Windows7
-- 12 - Windows7x64
-- 16 - Windows2008x64
-- 17 - Windows2008R2x64
-- 20 - Windows8
-- 21 - Windows8x64
-- 23 - Windows2012x64
-- 25 - Windows2012R2x64
-- 26 - Windows10
-- 27 - Windows10x64
-- 29 - Windows2016x64

COPY (
    WITH vms_win_with_timezone AS (
        SELECT
            vm_name,
            time_zone
        FROM
            vm_static
        WHERE
            os IN (
                1,
                3,
                4,
                10,
                11,
                12,
                16,
                17,
                20,
                21,
                23,
                25,
                26,
                27,
                29
        ) AND entity_type='VM'
    )

    SELECT
        vm_name AS "VM Name",
        time_zone AS "Time Zone"
    FROM
        vms_win_with_timezone
    WHERE
        time_zone NOT IN
        (
            SELECT zone FROM timezone_temp
        )
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP TABLE timezone_temp;
