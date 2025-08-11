/*
    Oflaz Paketleme Sistemi (remoteExec sürümü)
    - Dedicated server uyumlu
    - Client’ta action menüleri görünür
    - ACE’siz sürükleme / bırakma
    - Arma 3 default ikon ve animasyonlar
    - Ölüm süresi bilgisi eklenmiş
*/

// ========== CLIENT TARAFI ==========
if (hasInterface) then {
    [] spawn {
        sleep 1;
        systemChat "[OFLZ] Paketleme Sistemi yüklendi.";
    };

    oflz_fnc_addCorpseActions = {
        params ["_corpse"];
        if (isNull _corpse) exitWith {};

        // Aynı objeye tekrar eklenmesini engelle
        if (_corpse getVariable ["oflz_actions_added", false]) exitWith {};
        _corpse setVariable ["oflz_actions_added", true];

        // --- Ceset Bilgisi Action ---
        _corpse addAction [
            "<t color='#FFFFFF'>Ceset Bilgisi</t>",
            {
                params ["_target", "_caller"];
                private _info = "";
                private _deadName = _target getVariable ["deadName", ""];
                private _deathTime = _target getVariable ["deathTime", -1];

                if (_deadName != "") then {
                    if (_deathTime >= 0) then {
                        private _elapsed = time - _deathTime;
                        private _minutes = floor (_elapsed / 60);
                        private _seconds = floor (_elapsed mod 60);
                        private _hours   = floor (_minutes / 60);
                        _minutes = _minutes mod 60;

                        private _timeStr = if (_hours > 0) then {
                            format ["%1 saat %2 dakika", _hours, _minutes]
                        } else {
                            format ["%1 dakika %2 saniye", _minutes, _seconds]
                        };

                        _info = format ["Bu ceset %1'e ait. %2 önce öldü.", _deadName, _timeStr];
                    } else {
                        _info = format ["Bu ceset %1'e ait.", _deadName];
                    };
                } else {
                    _info = "Kime ait olduğu bilinmiyor.";
                };
                hint _info;
            },
            [],
            1.5,
            true,
            true,
            "",
            "_this distance _target < 3"
        ];

        // --- Paketleme sadece ceset (Man) için ---
        if (_corpse isKindOf "Man") then {
            [
                _corpse,
                "<t color='#FFCC00'>Cesedi Torbaya Koy</t>",
                "",
                "",
                "_this distance _target < 3",
                "_caller distance _target < 3",
                {},
                {},
                {
                    params ["_target", "_caller"];
                    private _pos = getPosATL _target;

                    // Torba oluştur
                    private _bag = createVehicle ["Land_Bodybag_01_black_F", _pos, [], 0, "CAN_COLLIDE"];
                    _bag setDir random 360;
                    _bag setVariable ["oflz_is_bodybag", true, true];
                    _bag setVariable ["beingDragged", false, true];
                    _bag setVariable ["deadName", _target getVariable ["deadName", name _target], true];
                    _bag setVariable ["deathTime", _target getVariable ["deathTime", -1], true];

                    deleteVehicle _target;

                    // --- Torbaya sürükleme action ---
                    _bag addAction [
                        "<t color='#3399FF'>Ceset Torbasını Sürükle</t>",
                        {
                            params ["_bagObj", "_caller"];
                            _bagObj setVariable ["beingDragged", true, true];
                            _bagObj setVariable ["draggedBy", _caller, true];

                            _bagObj attachTo [_caller, [0, 1.2, 0.05]];
                            _bagObj setVectorDirAndUp [[0,1,0],[0,0,1]];
                            _caller playMove "AmovPercMstpSnonWnonDnon_AcinPknlMwlkSnonWnonDb_2";

                            _caller addAction [
                                "<t color='#FF3333'>Ceset Torbasını Bırak</t>",
                                {
                                    params ["_target", "_caller", "_id"];
                                    private _bagObj = _caller getVariable ["draggingBag", objNull];
                                    if (!isNull _bagObj) then {
                                        detach _bagObj;
                                        _bagObj setVariable ["beingDragged", false, true];
                                        _bagObj setVariable ["draggedBy", objNull, true];
                                    };
                                    _caller removeAction _id;
                                    _caller setVariable ["draggingBag", objNull];
                                    _caller switchMove "";
                                    hint "Ceset torbasını bıraktın.";
                                },
                                [],
                                1.5,
                                true,
                                true,
                                "",
                                "",
                                5
                            ];

                            _caller setVariable ["draggingBag", _bagObj];
                            hint "Ceset torbasını sürüklüyorsun.";
                        },
                        [],
                        1.5,
                        true,
                        true,
                        "",
                        "!(_target getVariable ['beingDragged', false]) && _this distance _target < 3"
                    ];

                    // --- Torbaya saklama action ---
                    [
                        _bag,
                        "<t color='#00FF00'>Ceset Torbasını Sakla</t>",
                        "",
                        "",
                        "_this distance _target < 3 && !(_target getVariable ['beingDragged', false])",
                        "_caller distance _target < 3",
                        {},
                        {},
                        {
                            params ["_bagTarget", "_caller"];
                            deleteVehicle _bagTarget;
                            hint "Ceset torbası saklandı.";
                        },
                        {},
                        [],
                        20, 0, true, false
                    ] call BIS_fnc_holdActionAdd;

                    // Torbaya da ceset bilgisi ekle
                    [_bag] call oflz_fnc_addCorpseActions;
                },
                {},
                [],
                5, 0, true, false
            ] call BIS_fnc_holdActionAdd;
        };
    };
};

// ========== SERVER TARAFI ==========
if (isServer) then {
    [] spawn {
        sleep 1;
        systemChat "[OFLZ] Paketleme Sistemi yüklendi.";
    };

    {
        if (_x isKindOf "Man" && !alive _x) then {
            _x setVariable ["deadName", name _x, true];
            _x setVariable ["deathTime", time, true];
            [_x] remoteExec ["oflz_fnc_addCorpseActions", 0, true];
        };
    } forEach allDeadMen;

    addMissionEventHandler ["EntityKilled", {
        params ["_unit"];
        if (!isNull _unit && {_unit isKindOf "Man"}) then {
            _unit setVariable ["deadName", name _unit, true];
            _unit setVariable ["deathTime", time, true];
            [_unit] spawn {
                params ["_corpse"];
                sleep 0.5;
                [_corpse] remoteExec ["oflz_fnc_addCorpseActions", 0, true];
            };
        };
    }];
};
