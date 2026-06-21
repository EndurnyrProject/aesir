defmodule Aesir.Commons.Network.ProtoTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.ActionRequest
  alias Aesir.Net.CastCancel
  alias Aesir.Net.Character
  alias Aesir.Net.CharAuthFailed
  alias Aesir.Net.CharCreated
  alias Aesir.Net.CharCreateFailed
  alias Aesir.Net.CharList
  alias Aesir.Net.CharListRefresh
  alias Aesir.Net.CharServerInfo
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.ChatRequest
  alias Aesir.Net.CreateChar
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.DeleteCharAck
  alias Aesir.Net.DeleteCharRequest
  alias Aesir.Net.EnterAck
  alias Aesir.Net.Envelope
  alias Aesir.Net.EquipItem
  alias Aesir.Net.EquipResult
  alias Aesir.Net.GroundSkill
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.InventoryItem
  alias Aesir.Net.InventoryList
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.Knockback
  alias Aesir.Net.LoginRequest
  alias Aesir.Net.LoginResponse
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveStop
  alias Aesir.Net.NameRequest
  alias Aesir.Net.NameResponse
  alias Aesir.Net.ParamChange
  alias Aesir.Net.Respawn
  alias Aesir.Net.Resurrect
  alias Aesir.Net.SelectChar
  alias Aesir.Net.SelfMove
  alias Aesir.Net.SessionAuth
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SkillCooldown
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.Net.Snapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.Net.SpriteChange
  alias Aesir.Net.StatUp
  alias Aesir.Net.StatUpResult
  alias Aesir.Net.TimeSync
  alias Aesir.Net.TimeSyncAck
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UnequipResult
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitHp
  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.ZoneServerInfo

  test "envelope round-trips a login_request through the oneof body" do
    env = %Envelope{
      seq: 7,
      body:
        {:login_request,
         %LoginRequest{username: "neo", password: "pw", client_version: 20_211_103}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 7,
              body:
                {:login_request,
                 %LoginRequest{username: "neo", password: "pw", client_version: 20_211_103}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "login_response carries repeated char servers" do
    env = %Envelope{
      body:
        {:login_response,
         %LoginResponse{
           account_id: 2_000_000,
           login_id1: 111,
           login_id2: 222,
           sex: 0,
           auth_token: "deadbeef",
           char_servers: [
             %CharServerInfo{name: "Aesir", ip: "127.0.0.1", port: 6121, user_count: 3}
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:login_response,
                 %LoginResponse{
                   account_id: 2_000_000,
                   auth_token: "deadbeef",
                   char_servers: [%CharServerInfo{name: "Aesir", port: 6121, user_count: 3}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "session_auth round-trips through envelope oneof" do
    env = %Envelope{
      seq: 1,
      body:
        {:session_auth,
         %SessionAuth{account_id: 1_001, login_id1: 42, login_id2: 99, sex: 1, char_id: 7}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 1,
              body:
                {:session_auth,
                 %SessionAuth{account_id: 1_001, login_id1: 42, login_id2: 99, sex: 1, char_id: 7}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_list with nested characters round-trips through envelope oneof" do
    env = %Envelope{
      seq: 2,
      body:
        {:char_list,
         %CharList{
           account_id: 1_001,
           normal_slots: 15,
           premium_slots: 0,
           billing_slots: 0,
           producible_slots: 15,
           valid_slots: 15,
           page_count: 5,
           pincode_enabled: false,
           characters: [
             %Character{
               gid: 10_001,
               name: "Sigrid",
               class: 1,
               base_level: 99,
               job_level: 50,
               base_exp: 1_000_000,
               job_exp: 500_000,
               zeny: 99_999,
               hp: 5_000,
               max_hp: 5_000,
               sp: 1_000,
               max_sp: 1_000,
               str: 80,
               agi: 70,
               vit: 60,
               int: 40,
               dex: 90,
               luk: 30,
               status_point: 0,
               skill_point: 0,
               hair: 3,
               hair_color: 4,
               clothes_color: 0,
               weapon: 0,
               shield: 0,
               head_top: 0,
               head_mid: 0,
               head_bottom: 0,
               robe: 0,
               char_num: 0,
               last_map: "prontera",
               sex: 1,
               option: 0,
               karma: 0,
               manner: 0,
               rename: 0,
               delete_date: 0
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 2,
              body:
                {:char_list,
                 %CharList{
                   account_id: 1_001,
                   normal_slots: 15,
                   characters: [%Character{gid: 10_001, name: "Sigrid", base_level: 99}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_auth_failed round-trips through envelope oneof" do
    env = %Envelope{body: {:char_auth_failed, %CharAuthFailed{reason: 3}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:char_auth_failed, %CharAuthFailed{reason: 3}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "select_char round-trips through envelope oneof" do
    env = %Envelope{body: {:select_char, %SelectChar{slot: 2}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:select_char, %SelectChar{slot: 2}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "zone_server_info round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:zone_server_info,
         %ZoneServerInfo{char_id: 10_001, map_name: "prontera", ip: "127.0.0.1", port: 5121}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:zone_server_info,
                 %ZoneServerInfo{
                   char_id: 10_001,
                   map_name: "prontera",
                   ip: "127.0.0.1",
                   port: 5121
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "create_char round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:create_char,
         %CreateChar{
           name: "Freya",
           slot: 1,
           hair_color: 2,
           hair_style: 3,
           starting_job: 0,
           sex: 1
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:create_char,
                 %CreateChar{name: "Freya", slot: 1, hair_color: 2, hair_style: 3, sex: 1}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_created round-trips through envelope oneof" do
    env = %Envelope{
      body: {:char_created, %CharCreated{character: %Character{gid: 20_001, name: "Freya"}}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:char_created, %CharCreated{character: %Character{gid: 20_001, name: "Freya"}}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_create_failed round-trips through envelope oneof" do
    env = %Envelope{body: {:char_create_failed, %CharCreateFailed{reason_code: 3}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:char_create_failed, %CharCreateFailed{reason_code: 3}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "delete_char_request round-trips through envelope oneof" do
    env = %Envelope{body: {:delete_char_request, %DeleteCharRequest{char_id: 10_001}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:delete_char_request, %DeleteCharRequest{char_id: 10_001}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "delete_char_ack round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:delete_char_ack, %DeleteCharAck{char_id: 10_001, result: 0, delete_date: 1_750_000_000}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:delete_char_ack,
                 %DeleteCharAck{char_id: 10_001, result: 0, delete_date: 1_750_000_000}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "char_list_refresh round-trips through envelope oneof" do
    env = %Envelope{body: {:char_list_refresh, %CharListRefresh{}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:char_list_refresh, %CharListRefresh{}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "map_loaded round-trips through envelope oneof" do
    env = %Envelope{body: {:map_loaded, %MapLoaded{}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:map_loaded, %MapLoaded{}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "time_sync round-trips through envelope oneof" do
    env = %Envelope{body: {:time_sync, %TimeSync{client_tick: 123_456}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:time_sync, %TimeSync{client_tick: 123_456}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "time_sync_ack round-trips through envelope oneof" do
    env = %Envelope{body: {:time_sync_ack, %TimeSyncAck{server_tick: 654_321}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:time_sync_ack, %TimeSyncAck{server_tick: 654_321}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "enter_ack round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:enter_ack,
         %EnterAck{
           account_id: 2_000_000,
           x: 150,
           y: 100,
           dir: 4,
           start_time: 1_750_000_000,
           font: 0
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:enter_ack,
                 %EnterAck{
                   account_id: 2_000_000,
                   x: 150,
                   y: 100,
                   dir: 4,
                   start_time: 1_750_000_000,
                   font: 0
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "move_request round-trips through envelope oneof" do
    env = %Envelope{body: {:move_request, %MoveRequest{dest_x: 200, dest_y: 175}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:move_request, %MoveRequest{dest_x: 200, dest_y: 175}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "self_move round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:self_move,
         %SelfMove{src_x: 100, src_y: 100, dst_x: 105, dst_y: 110, start_time: 1_750_000_000}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:self_move,
                 %SelfMove{
                   src_x: 100,
                   src_y: 100,
                   dst_x: 105,
                   dst_y: 110,
                   start_time: 1_750_000_000
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "move_stop round-trips through envelope oneof" do
    env = %Envelope{body: {:move_stop, %MoveStop{gid: 10_001, x: 120, y: 130}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:move_stop, %MoveStop{gid: 10_001, x: 120, y: 130}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unit_spawn with moving fields round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:unit_spawn,
         %UnitSpawn{
           gid: 10_001,
           aid: 2_000_000,
           object_type: 0,
           job: 1,
           x: 150,
           y: 100,
           dir: 4,
           speed: 150,
           hp: 5_000,
           max_hp: 5_000,
           clevel: 99,
           name: "Sigrid",
           sex: 1,
           is_boss: false,
           moving: true,
           dst_x: 160,
           dst_y: 110,
           move_start_time: 1_750_000_000
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:unit_spawn,
                 %UnitSpawn{
                   gid: 10_001,
                   aid: 2_000_000,
                   job: 1,
                   x: 150,
                   y: 100,
                   name: "Sigrid",
                   moving: true,
                   dst_x: 160,
                   dst_y: 110,
                   move_start_time: 1_750_000_000
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unit_despawn round-trips through envelope oneof" do
    env = %Envelope{body: {:unit_despawn, %UnitDespawn{gid: 10_001, reason: 0}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:unit_despawn, %UnitDespawn{gid: 10_001, reason: 0}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "name_request round-trips through envelope oneof" do
    env = %Envelope{body: {:name_request, %NameRequest{entity_id: 10_001}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:name_request, %NameRequest{entity_id: 10_001}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "name_response round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:name_response,
         %NameResponse{
           gid: 10_001,
           name: "Sigrid",
           party_name: "Valhalla",
           guild_name: "Aesir",
           position_name: "Leader"
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:name_response,
                 %NameResponse{
                   gid: 10_001,
                   name: "Sigrid",
                   party_name: "Valhalla",
                   guild_name: "Aesir",
                   position_name: "Leader"
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "chat_request round-trips through envelope oneof" do
    env = %Envelope{body: {:chat_request, %ChatRequest{message: "hello world"}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:chat_request, %ChatRequest{message: "hello world"}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "chat_message round-trips through envelope oneof" do
    env = %Envelope{body: {:chat_message, %ChatMessage{gid: 10_001, message: "hello world"}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{body: {:chat_message, %ChatMessage{gid: 10_001, message: "hello world"}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "snapshot with nested entities round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:snapshot,
         %Snapshot{
           server_tick: 1_750_000_000,
           entities: [
             %SnapshotEntity{id: 10_001, x: 150, y: 100, dir: 4, move_state: 1, hp_pct: 75}
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:snapshot,
                 %Snapshot{
                   server_tick: 1_750_000_000,
                   entities: [
                     %SnapshotEntity{
                       id: 10_001,
                       x: 150,
                       y: 100,
                       dir: 4,
                       move_state: 1,
                       hp_pct: 75
                     }
                   ]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "action_request round-trips through envelope oneof" do
    env = %Envelope{body: {:action_request, %ActionRequest{target_id: 10_001, action: 7}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:action_request, %ActionRequest{target_id: 10_001, action: 7}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "damage_dealt preserves negative sint32 damage through envelope oneof" do
    env = %Envelope{
      body:
        {:damage_dealt,
         %DamageDealt{
           src_id: 2_000_000,
           target_id: 10_001,
           server_tick: 1_750_000_000,
           src_speed: 150,
           dmg_speed: 432,
           damage: -50,
           div: 1,
           type: 0,
           damage2: -25,
           is_sp_damage: false
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:damage_dealt,
                 %DamageDealt{
                   src_id: 2_000_000,
                   target_id: 10_001,
                   server_tick: 1_750_000_000,
                   damage: -50,
                   div: 1,
                   damage2: -25
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "knockback round-trips through envelope oneof" do
    env = %Envelope{body: {:knockback, %Knockback{unit_id: 10_001, dst_x: 120, dst_y: 130}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{body: {:knockback, %Knockback{unit_id: 10_001, dst_x: 120, dst_y: 130}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "skill_cast round-trips through envelope oneof" do
    env = %Envelope{
      body: {:skill_cast, %SkillCast{skill_id: 5, level: 10, target_id: 10_001}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{body: {:skill_cast, %SkillCast{skill_id: 5, level: 10, target_id: 10_001}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "ground_skill_cast round-trips through envelope oneof" do
    env = %Envelope{
      body: {:ground_skill_cast, %GroundSkillCast{skill_id: 17, level: 5, x: 150, y: 100}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:ground_skill_cast, %GroundSkillCast{skill_id: 17, level: 5, x: 150, y: 100}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "skill_list with nested skills round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:skill_list,
         %SkillList{
           skills: [
             %SkillInfo{
               skill_id: 5,
               type: 1,
               level: 10,
               sp: 15,
               range: 9,
               name: "NV_BASIC",
               upgradable: true
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:skill_list,
                 %SkillList{
                   skills: [
                     %SkillInfo{
                       skill_id: 5,
                       type: 1,
                       level: 10,
                       sp: 15,
                       range: 9,
                       name: "NV_BASIC",
                       upgradable: true
                     }
                   ]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "skill_damage preserves negative sint32 damage through envelope oneof" do
    env = %Envelope{
      body:
        {:skill_damage,
         %SkillDamage{
           skill_id: 5,
           level: 10,
           src_id: 2_000_000,
           target_id: 10_001,
           server_tick: 1_750_000_000,
           damage: -100,
           div: 1,
           type: 0,
           src_delay: 300,
           dst_delay: 432
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:skill_damage,
                 %SkillDamage{skill_id: 5, level: 10, src_id: 2_000_000, damage: -100, div: 1}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "skill_effect round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:skill_effect,
         %SkillEffect{skill_id: 28, level: 10, src_id: 2_000_000, target_id: 10_001, result: 1}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:skill_effect,
                 %SkillEffect{
                   skill_id: 28,
                   level: 10,
                   src_id: 2_000_000,
                   target_id: 10_001,
                   result: 1
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "skill_casting round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:skill_casting,
         %SkillCasting{
           src_id: 2_000_000,
           target_id: 10_001,
           x: 0,
           y: 0,
           skill_id: 14,
           property: 3,
           cast_time: 1_500
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:skill_casting,
                 %SkillCasting{
                   src_id: 2_000_000,
                   target_id: 10_001,
                   skill_id: 14,
                   property: 3,
                   cast_time: 1_500
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "cast_cancel round-trips through envelope oneof" do
    env = %Envelope{body: {:cast_cancel, %CastCancel{gid: 10_001}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:cast_cancel, %CastCancel{gid: 10_001}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "skill_cooldown round-trips through envelope oneof" do
    env = %Envelope{body: {:skill_cooldown, %SkillCooldown{skill_id: 5, tick: 2_000}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:skill_cooldown, %SkillCooldown{skill_id: 5, tick: 2_000}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "ground_skill round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:ground_skill,
         %GroundSkill{
           skill_id: 17,
           src_id: 2_000_000,
           level: 5,
           x: 150,
           y: 100,
           server_tick: 1_750_000_000
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:ground_skill,
                 %GroundSkill{
                   skill_id: 17,
                   src_id: 2_000_000,
                   level: 5,
                   x: 150,
                   y: 100,
                   server_tick: 1_750_000_000
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "equip_item round-trips through envelope oneof" do
    env = %Envelope{body: {:equip_item, %EquipItem{index: 3, position: 2}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:equip_item, %EquipItem{index: 3, position: 2}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unequip_item round-trips through envelope oneof" do
    env = %Envelope{body: {:unequip_item, %UnequipItem{index: 3}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:unequip_item, %UnequipItem{index: 3}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "equip_result round-trips through envelope oneof" do
    env = %Envelope{
      body: {:equip_result, %EquipResult{index: 3, wear_location: 2, view_id: 1_201, result: 0}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:equip_result,
                 %EquipResult{index: 3, wear_location: 2, view_id: 1_201, result: 0}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unequip_result round-trips through envelope oneof" do
    env = %Envelope{
      body: {:unequip_result, %UnequipResult{index: 3, wear_location: 2, result: 0}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:unequip_result, %UnequipResult{index: 3, wear_location: 2, result: 0}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "inventory_list with nested normal and equip items round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:inventory_list,
         %InventoryList{
           normal: [
             %InventoryItem{index: 0, nameid: 501, type: 0, amount: 10, identified: true}
           ],
           equip: [
             %InventoryItem{
               index: 1,
               nameid: 1_201,
               type: 4,
               amount: 1,
               location: 2,
               identified: true,
               refine: 7,
               cards: [4_001, 0, 0, 0]
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:inventory_list,
                 %InventoryList{
                   normal: [
                     %InventoryItem{index: 0, nameid: 501, amount: 10, identified: true}
                   ],
                   equip: [
                     %InventoryItem{
                       index: 1,
                       nameid: 1_201,
                       refine: 7,
                       cards: [4_001, 0, 0, 0]
                     }
                   ]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "item_added with cards round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:item_added,
         %ItemAdded{
           index: 5,
           amount: 1,
           nameid: 1_201,
           identified: true,
           refine: 0,
           cards: [4_001, 0, 0, 0],
           location: 2,
           type: 4,
           result: 0
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:item_added,
                 %ItemAdded{
                   index: 5,
                   amount: 1,
                   nameid: 1_201,
                   identified: true,
                   cards: [4_001, 0, 0, 0],
                   location: 2,
                   type: 4
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "item_removed round-trips through envelope oneof" do
    env = %Envelope{body: {:item_removed, %ItemRemoved{index: 5, amount: 1, reason: 0}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:item_removed, %ItemRemoved{index: 5, amount: 1, reason: 0}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "stat_up round-trips through envelope oneof" do
    env = %Envelope{body: {:stat_up, %StatUp{stat_id: 13, amount: 1}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:stat_up, %StatUp{stat_id: 13, amount: 1}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "stat_up_result round-trips through envelope oneof" do
    env = %Envelope{body: {:stat_up_result, %StatUpResult{stat_id: 13, ok: true, value: 80}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{body: {:stat_up_result, %StatUpResult{stat_id: 13, ok: true, value: 80}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "param_change carries a 64-bit value through envelope oneof" do
    env = %Envelope{body: {:param_change, %ParamChange{var_id: 1, value: 5_000_000_000}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:param_change, %ParamChange{var_id: 1, value: 5_000_000_000}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unit_hp round-trips through envelope oneof" do
    env = %Envelope{body: {:unit_hp, %UnitHp{id: 10_001, hp: 4_200, max_hp: 5_000}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:unit_hp, %UnitHp{id: 10_001, hp: 4_200, max_hp: 5_000}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "sprite_change round-trips through envelope oneof" do
    env = %Envelope{
      body: {:sprite_change, %SpriteChange{gid: 10_001, type: 2, val: 1_201, val2: 0}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:sprite_change, %SpriteChange{gid: 10_001, type: 2, val: 1_201, val2: 0}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "resurrect round-trips through envelope oneof" do
    env = %Envelope{body: {:resurrect, %Resurrect{gid: 10_001, type: 0}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:resurrect, %Resurrect{gid: 10_001, type: 0}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "respawn round-trips through envelope oneof" do
    env = %Envelope{body: {:respawn, %Respawn{type: 0}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:respawn, %Respawn{type: 0}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end
end
