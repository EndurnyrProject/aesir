defmodule Aesir.Commons.Network.ProtoTest do
  use ExUnit.Case, async: true

  alias Aesir.LegacyNet.Hello, as: LegacyHello
  alias Aesir.LegacyNet.HelloAck, as: LegacyHelloAck
  alias Aesir.LegacyNet.SkillUnitCellState, as: LegacySkillUnitCellState
  alias Aesir.LegacyNet.SkillUnitGroupState, as: LegacySkillUnitGroupState
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.Announcement
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartItemRemoved
  alias Aesir.Net.CartMountRequest
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
  alias Aesir.Net.EstimationResult
  alias Aesir.Net.GroundSkill
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.GuildDisbanded
  alias Aesir.Net.GuildEmblemChanged
  alias Aesir.Net.GuildEmblemData
  alias Aesir.Net.GuildEmblemRequest
  alias Aesir.Net.GuildEmblemUploadRequest
  alias Aesir.Net.GuildExpelRequest
  alias Aesir.Net.GuildInfo
  alias Aesir.Net.GuildInviteNotify
  alias Aesir.Net.GuildInviteRequest
  alias Aesir.Net.GuildInviteResponse
  alias Aesir.Net.GuildLeaveRequest
  alias Aesir.Net.GuildLevelUp
  alias Aesir.Net.GuildMember
  alias Aesir.Net.GuildMemberPositionRequest
  alias Aesir.Net.GuildMemberUpdate
  alias Aesir.Net.GuildNoticeEditRequest
  alias Aesir.Net.GuildPosition
  alias Aesir.Net.GuildPositionEditRequest
  alias Aesir.Net.GuildSkillEntry
  alias Aesir.Net.GuildSkillUpRequest
  alias Aesir.Net.Hello
  alias Aesir.Net.HelloAck
  alias Aesir.Net.HomunculusAiConfig
  alias Aesir.Net.HomunculusAiSkillConfig
  alias Aesir.Net.HomunculusAttackCommand
  alias Aesir.Net.HomunculusCastSkillCommand
  alias Aesir.Net.HomunculusCooldown
  alias Aesir.Net.HomunculusDeleteCommand
  alias Aesir.Net.HomunculusDisplayedStats
  alias Aesir.Net.HomunculusFeedCommand
  alias Aesir.Net.HomunculusFollowCommand
  alias Aesir.Net.HomunculusHpRange
  alias Aesir.Net.HomunculusHpThreshold
  alias Aesir.Net.HomunculusInspectCommand
  alias Aesir.Net.HomunculusLearnSkillCommand
  alias Aesir.Net.HomunculusMoveCommand
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.HomunculusRenameCommand
  alias Aesir.Net.HomunculusReplaceAiCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusRestCommand
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.HomunculusSkillMetadata
  alias Aesir.Net.HomunculusStandbyCommand
  alias Aesir.Net.InventoryItem
  alias Aesir.Net.InventoryList
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemBound
  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.ItemVanished
  alias Aesir.Net.Knockback
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.LearnSkillResult
  alias Aesir.Net.LoginRequest
  alias Aesir.Net.LoginResponse
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MountRequest
  alias Aesir.Net.MountResult
  alias Aesir.Net.MoveFromCartRequest
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveStop
  alias Aesir.Net.MoveToCartRequest
  alias Aesir.Net.NameRequest
  alias Aesir.Net.NameResponse
  alias Aesir.Net.NpcBuyEntry
  alias Aesir.Net.NpcBuyRequest
  alias Aesir.Net.NpcBuyResult
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.NpcSellEntry
  alias Aesir.Net.NpcSellRequest
  alias Aesir.Net.NpcSellResult
  alias Aesir.Net.NpcShopBuyItem
  alias Aesir.Net.NpcShopOpen
  alias Aesir.Net.NpcShopSellItem
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.ParamChange
  alias Aesir.Net.PartyActionResult
  alias Aesir.Net.PartyCreateRequest
  alias Aesir.Net.PartyDisbanded
  alias Aesir.Net.PartyInfo
  alias Aesir.Net.PartyInviteNotify
  alias Aesir.Net.PartyInviteRequest
  alias Aesir.Net.PartyInviteResponse
  alias Aesir.Net.PartyKickRequest
  alias Aesir.Net.PartyLeaderRequest
  alias Aesir.Net.PartyLeaveRequest
  alias Aesir.Net.PartyMember
  alias Aesir.Net.PartyMemberUpdate
  alias Aesir.Net.PartyOptionsRequest
  alias Aesir.Net.PickupItemRequest
  alias Aesir.Net.PickupResult
  alias Aesir.Net.ProductionResult
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
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Net.SkillTextInputReply
  alias Aesir.Net.SkillTextInputRequest
  alias Aesir.Net.SkillUnitCellState
  alias Aesir.Net.SkillUnitDespawn
  alias Aesir.Net.SkillUnitGroupState
  alias Aesir.Net.SkillUnitSnapshot
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.Net.SkillUnitUpdate
  alias Aesir.Net.Snapshot
  alias Aesir.Net.SnapshotEntity
  alias Aesir.Net.SpecialEffect
  alias Aesir.Net.SpiritSphereUpdate
  alias Aesir.Net.SpriteChange
  alias Aesir.Net.StatUp
  alias Aesir.Net.StatUpResult
  alias Aesir.Net.StatusChange
  alias Aesir.Net.StorageCloseRequest
  alias Aesir.Net.StorageDepositRequest
  alias Aesir.Net.StorageItemAdded
  alias Aesir.Net.StorageItemRemoved
  alias Aesir.Net.StorageOpened
  alias Aesir.Net.StorageResult
  alias Aesir.Net.StorageWithdrawRequest
  alias Aesir.Net.TimeSync
  alias Aesir.Net.TimeSyncAck
  alias Aesir.Net.TradeAddItem
  alias Aesir.Net.TradeOfferUpdate
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UnequipResult
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitHp
  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.UnitStateChange
  alias Aesir.Net.UseItem
  alias Aesir.Net.VendingBoardShown
  alias Aesir.Net.VendingBuy
  alias Aesir.Net.VendingEntry
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingPurchaseRequest
  alias Aesir.Net.VendingSaleReport
  alias Aesir.Net.VendingShopItem
  alias Aesir.Net.ZoneServerInfo

  test "Homunculus envelope fields append at 169 through 171" do
    fields = Envelope.schema().fields

    assert fields.homunculus_request.tag == 169
    assert fields.homunculus_result.tag == 170
    assert fields.homunculus_private_state.tag == 171
  end

  test "trade messages round-trip through reserved envelope fields" do
    assert_round_trip(:trade_add_item, %TradeAddItem{index: 3, amount: 10})

    assert_round_trip(:trade_offer_update, %TradeOfferUpdate{
      own: [%InventoryItem{index: 3, nameid: 501, amount: 10, signer_name: "Odin", creator_id: 7}],
      partner: [
        %InventoryItem{
          index: 5,
          nameid: 1_201,
          amount: 1,
          refine: 7,
          cards: [4_001, 0, 0, 0],
          creator_kind: :CREATOR_FORGED
        }
      ],
      own_zeny: 99_999,
      partner_zeny: 1_000,
      own_locked: true
    })

    fields = Envelope.schema().fields

    assert fields.trade_request.tag == 173
    assert fields.trade_response.tag == 174
    assert fields.trade_add_item.tag == 175
    assert fields.trade_remove_item.tag == 176
    assert fields.trade_set_zeny.tag == 177
    assert fields.trade_lock.tag == 178
    assert fields.trade_confirm.tag == 179
    assert fields.trade_cancel.tag == 180
    assert fields.trade_request_received.tag == 181
    assert fields.trade_opened.tag == 182
    assert fields.trade_offer_update.tag == 183
    assert fields.trade_completed.tag == 184
    assert fields.trade_cancelled.tag == 185
  end

  test "inventory item bound round-trips as the BoundType enum" do
    assert_round_trip(
      :inventory_list,
      %InventoryList{
        normal: [%InventoryItem{index: 3, nameid: 501, amount: 1, bound: :BOUND_ACCOUNT}]
      }
    )
  end

  test "every Homunculus command arm round-trips without an ownership selector" do
    commands = [
      inspect: %HomunculusInspectCommand{},
      move: %HomunculusMoveCommand{x: -10, y: 320},
      follow: %HomunculusFollowCommand{},
      attack: %HomunculusAttackCommand{target_id: 77},
      standby: %HomunculusStandbyCommand{},
      cast_skill: %HomunculusCastSkillCommand{skill_id: 8_001, level: 5, target: {:target_id, 77}},
      cast_skill: %HomunculusCastSkillCommand{skill_id: 8_002, level: 3, target: {:self, true}},
      feed: %HomunculusFeedCommand{},
      rename: %HomunculusRenameCommand{name: "Hildr"},
      rest: %HomunculusRestCommand{},
      delete: %HomunculusDeleteCommand{confirmed: true},
      replace_ai: %HomunculusReplaceAiCommand{config: complete_homunculus_ai_config()},
      learn_skill: %HomunculusLearnSkillCommand{skill_id: 8_003}
    ]

    assert Map.keys(HomunculusRequest.schema().fields) |> Enum.sort() ==
             [
               :attack,
               :cast_skill,
               :delete,
               :feed,
               :follow,
               :inspect,
               :learn_skill,
               :move,
               :rename,
               :replace_ai,
               :request_id,
               :rest,
               :standby
             ]

    for {tag, command} <- commands do
      assert_round_trip(:homunculus_request, %HomunculusRequest{
        request_id: 9_223_372_036_854_775_807,
        command: {tag, command}
      })
    end
  end

  test "Homunculus results round-trip every stable error with correlation" do
    errors = [
      :HOMUNCULUS_ERROR_NONE,
      :HOMUNCULUS_ERROR_NO_COMPANION,
      :HOMUNCULUS_ERROR_MALFORMED_COMMAND,
      :HOMUNCULUS_ERROR_WRONG_CHANNEL,
      :HOMUNCULUS_ERROR_INVALID_LIFECYCLE,
      :HOMUNCULUS_ERROR_INVALID_POSITION,
      :HOMUNCULUS_ERROR_INVALID_TARGET,
      :HOMUNCULUS_ERROR_OUT_OF_RANGE,
      :HOMUNCULUS_ERROR_SKILL_NOT_LEARNED,
      :HOMUNCULUS_ERROR_INVALID_SKILL_RANK,
      :HOMUNCULUS_ERROR_ON_COOLDOWN,
      :HOMUNCULUS_ERROR_INSUFFICIENT_SP,
      :HOMUNCULUS_ERROR_MISSING_ITEM,
      :HOMUNCULUS_ERROR_HP_GATE,
      :HOMUNCULUS_ERROR_RENAME_NOT_ALLOWED,
      :HOMUNCULUS_ERROR_INVALID_NAME,
      :HOMUNCULUS_ERROR_CONFIRMATION_REQUIRED,
      :HOMUNCULUS_ERROR_INVALID_AI_CONFIG,
      :HOMUNCULUS_ERROR_INSUFFICIENT_SKILL_POINTS,
      :HOMUNCULUS_ERROR_PREREQUISITES_NOT_MET,
      :HOMUNCULUS_ERROR_BUSY
    ]

    for error <- errors do
      assert_round_trip(:homunculus_result, %HomunculusResult{
        request_id: 42,
        success: error == :HOMUNCULUS_ERROR_NONE,
        error: error,
        state: if(error == :HOMUNCULUS_ERROR_NONE, do: complete_homunculus_private_state())
      })
    end
  end

  test "Homunculus enum zero values and optional HP threshold presence round-trip" do
    assert %HomunculusAiConfig{}.stance == :HOMUNCULUS_AI_STANCE_UNSPECIFIED
    assert %HomunculusAiSkillConfig{}.mode == :HOMUNCULUS_AI_SKILL_MODE_UNSPECIFIED
    assert %HomunculusPrivateState{}.lifecycle == :HOMUNCULUS_LIFECYCLE_UNSPECIFIED
    assert %HomunculusPrivateState{}.activity == :HOMUNCULUS_ACTIVITY_UNSPECIFIED
    assert %HomunculusPrivateState{}.intimacy_grade == :HOMUNCULUS_INTIMACY_GRADE_UNSPECIFIED

    without_threshold = %HomunculusAiSkillConfig{skill_id: 1}

    with_zero_threshold = %HomunculusAiSkillConfig{
      skill_id: 1,
      self_hp_threshold: %HomunculusHpThreshold{percent: 0}
    }

    assert decode(without_threshold).self_hp_threshold == nil
    assert decode(with_zero_threshold).self_hp_threshold == %HomunculusHpThreshold{percent: 0}
  end

  test "complete Homunculus owner-private state round-trips boundaries and AI rows" do
    state = complete_homunculus_private_state()

    assert state.intimacy_hundredths == 100_000
    assert state.cooldowns == [%HomunculusCooldown{skill_id: 8_001, remaining_ms: 140_000}]
    assert length(state.ai_config.skills) == 2
    assert_round_trip(:homunculus_private_state, state)
  end

  test "Hello and HelloAck omit capabilities without changing the protocol version" do
    for message <- [%Hello{protocol_version: 1, build: "legacy"}, %HelloAck{protocol_version: 1}] do
      {:ok, iodata, _size} = message.__struct__.encode(message)

      assert {:ok, decoded} = message.__struct__.decode(IO.iodata_to_binary(iodata))
      assert decoded.protocol_version == 1
      assert decoded.capabilities == []
    end
  end

  test "skill text input messages round-trip through their reserved envelope fields" do
    request = %SkillTextInputRequest{request_id: 4_294_967_296, skill_id: 125, max_utf8_bytes: 79}

    assert_round_trip(:skill_text_input_request, request)

    assert_round_trip(:skill_text_input_reply, %SkillTextInputReply{
      request_id: 4_294_967_296,
      outcome: {:text, "For Odin"}
    })

    assert_round_trip(:skill_text_input_reply, %SkillTextInputReply{
      request_id: 4_294_967_296,
      outcome: {:cancel, true}
    })

    assert Envelope.schema().fields.skill_text_input_request.tag == 166
    assert Envelope.schema().fields.skill_text_input_reply.tag == 167
  end

  test "skill unit phase defaults to active and round-trips every lifecycle phase" do
    assert %SkillUnitGroupState{}.phase == :SKILL_UNIT_PHASE_ACTIVE
    assert SkillUnitGroupState.schema().fields.phase.tag == 11

    for phase <- [
          :SKILL_UNIT_PHASE_ACTIVE,
          :SKILL_UNIT_PHASE_USED,
          :SKILL_UNIT_PHASE_SPRUNG,
          :SKILL_UNIT_PHASE_CAPTURED
        ] do
      assert_round_trip(:skill_unit_spawn, %SkillUnitSpawn{
        group: %SkillUnitGroupState{phase: phase}
      })
    end
  end

  test "old-schema decoders ignore capabilities and phases while retaining known fields" do
    for {message, legacy_module, expected} <- [
          {%Hello{
             protocol_version: 1,
             build: "capable",
             capabilities: [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]
           }, LegacyHello, %LegacyHello{protocol_version: 1, build: "capable"}},
          {%HelloAck{
             protocol_version: 1,
             accepted: true,
             capabilities: [:FEATURE_CAPABILITY_SKILL_TEXT_INPUT]
           }, LegacyHelloAck, %LegacyHelloAck{protocol_version: 1, accepted: true}}
        ] do
      assert {:ok, decoded} = legacy_module.decode(encode(message))
      assert Map.delete(decoded, :__uf__) == Map.delete(expected, :__uf__)
    end

    group = %SkillUnitGroupState{
      group_id: 1,
      skill_id: 125,
      skill_level: 1,
      owner_type: :SKILL_UNIT_OWNER_TYPE_PLAYER,
      owner_id: 2,
      center_x: 3,
      center_y: 4,
      created_tick: 5,
      expires_tick: 6,
      cells: [%SkillUnitCellState{cell_id: 7, x: 8, y: 9, hp: 10, max_hp: 11, flags: 12}],
      phase: :SKILL_UNIT_PHASE_CAPTURED
    }

    expected = %LegacySkillUnitGroupState{
      group_id: 1,
      skill_id: 125,
      skill_level: 1,
      owner_type: :SKILL_UNIT_OWNER_TYPE_PLAYER,
      owner_id: 2,
      center_x: 3,
      center_y: 4,
      created_tick: 5,
      expires_tick: 6,
      cells: [%LegacySkillUnitCellState{cell_id: 7, x: 8, y: 9, hp: 10, max_hp: 11, flags: 12}]
    }

    assert {:ok, decoded} = LegacySkillUnitGroupState.decode(encode(group))
    assert Map.delete(decoded, :__uf__) == Map.delete(expected, :__uf__)
  end

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

  test "unit_spawn with moving and spirit-sphere fields round-trips through envelope oneof" do
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
           move_start_time: 1_750_000_000,
           spirit_sphere_count: 4_294_967_295,
           spirit_sphere_revision: 4_294_967_296
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
                   move_start_time: 1_750_000_000,
                   spirit_sphere_count: 4_294_967_295,
                   spirit_sphere_revision: 4_294_967_296
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "spirit sphere protocol fields use the assigned schema tags" do
    assert UnitSpawn.schema().fields.spirit_sphere_count.tag == 36
    assert UnitSpawn.schema().fields.spirit_sphere_revision.tag == 37
    assert Envelope.schema().fields.spirit_sphere_update.tag == 163

    assert Map.keys(SnapshotEntity.schema().fields) == [:id, :x, :y, :dir, :move_state, :hp_pct]
  end

  test "spirit_sphere_update round-trips absolute state through envelope oneof" do
    assert_round_trip(
      :spirit_sphere_update,
      %SpiritSphereUpdate{unit_id: 1, count: 2, revision: 3}
    )
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

  test "damage_dealt retains primary, presentation-division, and secondary field numbers" do
    fields = DamageDealt.schema().fields

    assert fields.damage.tag == 6
    assert fields.div.tag == 7
    assert fields.damage2.tag == 9

    assert Map.keys(fields) |> Enum.sort() ==
             [
               :damage,
               :damage2,
               :div,
               :dmg_speed,
               :is_sp_damage,
               :server_tick,
               :src_id,
               :src_speed,
               :target_id,
               :type
             ]
  end

  test "damage_dealt preserves explicit signed nonzero components through envelope oneof" do
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

  test "item_bound round-trips through envelope oneof" do
    env = %Envelope{seq: 1, body: {:item_bound, %ItemBound{index: 3, bound: :BOUND_ACCOUNT}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{seq: 1, body: {:item_bound, %ItemBound{index: 3, bound: :BOUND_ACCOUNT}}}} =
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

  test "learn_skill round-trips through envelope oneof" do
    env = %Envelope{body: {:learn_skill, %LearnSkill{skill_id: 2}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:learn_skill, %LearnSkill{skill_id: 2}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "learn_skill_result round-trips through envelope oneof" do
    env =
      %Envelope{body: {:learn_skill_result, %LearnSkillResult{skill_id: 2, ok: true, reason: 0}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:learn_skill_result, %LearnSkillResult{skill_id: 2, ok: true, reason: 0}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "use_item round-trips through envelope oneof" do
    env = %Envelope{body: {:use_item, %UseItem{index: 7}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:use_item, %UseItem{index: 7}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "item_use_result round-trips through envelope oneof" do
    env =
      %Envelope{body: {:item_use_result, %ItemUseResult{index: 7, ok: true, reason: 0}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:item_use_result, %ItemUseResult{index: 7, ok: true, reason: 0}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "status_change round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:status_change,
         %StatusChange{
           unit_id: 10_001,
           efst: 0,
           on: true,
           total_ms: 30_000,
           remain_ms: 12_500,
           val1: 5,
           val2: -3,
           val3: 0
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:status_change,
                 %StatusChange{
                   unit_id: 10_001,
                   efst: 0,
                   on: true,
                   total_ms: 30_000,
                   remain_ms: 12_500,
                   val1: 5,
                   val2: -3,
                   val3: 0
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unit_state_change round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:unit_state_change,
         %UnitStateChange{
           unit_id: 10_001,
           body_state: 1,
           health_state: 32,
           effect_state: 2,
           virtue: 4
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:unit_state_change,
                 %UnitStateChange{
                   unit_id: 10_001,
                   body_state: 1,
                   health_state: 32,
                   effect_state: 2,
                   virtue: 4
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "special_effect round-trips through envelope oneof" do
    env = %Envelope{body: {:special_effect, %SpecialEffect{source_id: 2_000_000, effect_id: 42}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:special_effect, %SpecialEffect{source_id: 2_000_000, effect_id: 42}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unit_spawn carries the sprite-state fields through envelope oneof" do
    env = %Envelope{
      body:
        {:unit_spawn,
         %UnitSpawn{
           gid: 10_001,
           body_state: 3,
           health_state: 16,
           effect_state: 8,
           virtue: 4
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:unit_spawn,
                 %UnitSpawn{
                   gid: 10_001,
                   body_state: 3,
                   health_state: 16,
                   effect_state: 8,
                   virtue: 4
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "skill_info exposes the enriched tree fields" do
    info = %SkillInfo{
      skill_id: 2,
      job_id: 1,
      type: 0,
      level: 1,
      sp: 8,
      range: 1,
      name: "SM_SWORD",
      upgradable: true,
      max_level: 10,
      requires: [%Aesir.Net.SkillRequirement{skill_id: 1, level: 1}],
      req_base_level: 0,
      req_job_level: 0
    }

    assert info.max_level == 10
    assert info.job_id == 1
    assert info.req_base_level == 0
    assert info.req_job_level == 0
    assert [%Aesir.Net.SkillRequirement{skill_id: 1, level: 1}] = info.requires
  end

  test "npc_talk round-trips through envelope oneof" do
    env = %Envelope{body: {:npc_talk, %NpcTalk{npc_id: 10_001}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:npc_talk, %NpcTalk{npc_id: 10_001}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "npc_dialog round-trips every Expect enum value (plus text and options) through envelope oneof" do
    for expect <- [:NEXT, :MENU, :INPUT_INT, :INPUT_STR, :CLOSE] do
      dialog = %NpcDialog{
        npc_id: 10_001,
        text: "Pick one\nor the other",
        expect: expect,
        options: ["Yes", "No"]
      }

      env = %Envelope{body: {:npc_dialog, dialog}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok, %Envelope{body: {:npc_dialog, ^dialog}}} =
               Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "cart_info with nested items round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:cart_info,
         %CartInfo{
           items: [
             %InventoryItem{index: 0, nameid: 501, type: 0, amount: 10, identified: true}
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:cart_info,
                 %CartInfo{
                   items: [%InventoryItem{index: 0, nameid: 501, amount: 10, identified: true}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "cart_item_added with cards round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:cart_item_added,
         %CartItemAdded{
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
                {:cart_item_added,
                 %CartItemAdded{
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

  test "cart_item_removed round-trips through envelope oneof" do
    env = %Envelope{body: {:cart_item_removed, %CartItemRemoved{index: 5, amount: 1, reason: 0}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:cart_item_removed, %CartItemRemoved{index: 5, amount: 1, reason: 0}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "cart_mount_request round-trips through envelope oneof" do
    env = %Envelope{body: {:cart_mount_request, %CartMountRequest{mount: true}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:cart_mount_request, %CartMountRequest{mount: true}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "move_to_cart_request round-trips through envelope oneof" do
    env =
      %Envelope{
        body: {:move_to_cart_request, %MoveToCartRequest{inventory_index: 3, amount: 10}}
      }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:move_to_cart_request, %MoveToCartRequest{inventory_index: 3, amount: 10}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "move_from_cart_request round-trips through envelope oneof" do
    env =
      %Envelope{body: {:move_from_cart_request, %MoveFromCartRequest{cart_index: 4, amount: 5}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:move_from_cart_request, %MoveFromCartRequest{cart_index: 4, amount: 5}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "vending_open_request with nested entries round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:vending_open_request,
         %VendingOpenRequest{
           title: "Cheap potions",
           entries: [%VendingEntry{cart_index: 0, amount: 5, price: 1_200}]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:vending_open_request,
                 %VendingOpenRequest{
                   title: "Cheap potions",
                   entries: [%VendingEntry{cart_index: 0, amount: 5, price: 1_200}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "vending_list with nested shop items round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:vending_list,
         %VendingList{
           vendor_unit_id: 10_001,
           title: "Cheap potions",
           items: [
             %VendingShopItem{
               index: 0,
               nameid: 501,
               type: 0,
               amount: 5,
               identified: true,
               refine: 0,
               cards: [0, 0, 0, 0],
               price: 1_200
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:vending_list,
                 %VendingList{
                   vendor_unit_id: 10_001,
                   title: "Cheap potions",
                   items: [
                     %VendingShopItem{
                       index: 0,
                       nameid: 501,
                       amount: 5,
                       identified: true,
                       price: 1_200
                     }
                   ]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "vending_purchase_request with nested buys round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:vending_purchase_request,
         %VendingPurchaseRequest{
           vendor_unit_id: 10_001,
           items: [%VendingBuy{index: 0, amount: 2}]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:vending_purchase_request,
                 %VendingPurchaseRequest{
                   vendor_unit_id: 10_001,
                   items: [%VendingBuy{index: 0, amount: 2}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "vending_board_shown round-trips through envelope oneof" do
    env = %Envelope{
      body: {:vending_board_shown, %VendingBoardShown{unit_id: 10_001, title: "Shop"}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:vending_board_shown, %VendingBoardShown{unit_id: 10_001, title: "Shop"}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "vending_sale_report round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:vending_sale_report,
         %VendingSaleReport{
           index: 0,
           nameid: 501,
           amount: 2,
           zeny_gained: 2_400,
           buyer_name: "Loki"
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:vending_sale_report,
                 %VendingSaleReport{
                   index: 0,
                   nameid: 501,
                   amount: 2,
                   zeny_gained: 2_400,
                   buyer_name: "Loki"
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "npc_shop_open with nested buy and sell items round-trips through envelope oneof" do
    env = %Envelope{
      seq: 1,
      body:
        {:npc_shop_open,
         %NpcShopOpen{
           unit_id: 1,
           buy_items: [%NpcShopBuyItem{nameid: 501, type: 0, price: 50}],
           sell_items: [
             %NpcShopSellItem{
               inventory_index: 3,
               nameid: 502,
               type: 0,
               amount: 7,
               sell_price: 25
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 1,
              body:
                {:npc_shop_open,
                 %NpcShopOpen{
                   unit_id: 1,
                   buy_items: [%NpcShopBuyItem{nameid: 501, type: 0, price: 50}],
                   sell_items: [
                     %NpcShopSellItem{
                       inventory_index: 3,
                       nameid: 502,
                       amount: 7,
                       sell_price: 25
                     }
                   ]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "npc_buy_request with nested entries round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:npc_buy_request,
         %NpcBuyRequest{unit_id: 1, items: [%NpcBuyEntry{nameid: 501, amount: 3}]}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:npc_buy_request,
                 %NpcBuyRequest{unit_id: 1, items: [%NpcBuyEntry{nameid: 501, amount: 3}]}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "npc_sell_request with nested entries round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:npc_sell_request,
         %NpcSellRequest{unit_id: 1, items: [%NpcSellEntry{inventory_index: 3, amount: 2}]}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:npc_sell_request,
                 %NpcSellRequest{
                   unit_id: 1,
                   items: [%NpcSellEntry{inventory_index: 3, amount: 2}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "npc_buy_result round-trips through envelope oneof" do
    env = %Envelope{body: {:npc_buy_result, %NpcBuyResult{result: 1}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:npc_buy_result, %NpcBuyResult{result: 1}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "npc_sell_result round-trips through envelope oneof" do
    env = %Envelope{body: {:npc_sell_result, %NpcSellResult{result: 2}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:npc_sell_result, %NpcSellResult{result: 2}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "item_on_ground round-trips through envelope oneof" do
    env = %Envelope{
      seq: 1,
      body:
        {:item_on_ground,
         %ItemOnGround{
           ground_id: 42,
           nameid: 501,
           amount: 3,
           x: 150,
           y: 100,
           identified: true,
           is_falling: true,
           sub_x: 4,
           sub_y: 7
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 1,
              body:
                {:item_on_ground,
                 %ItemOnGround{
                   ground_id: 42,
                   nameid: 501,
                   amount: 3,
                   x: 150,
                   y: 100,
                   identified: true,
                   is_falling: true,
                   sub_x: 4,
                   sub_y: 7
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "item_vanished round-trips every reason through envelope oneof" do
    for reason <- [:PICKED_UP, :EXPIRED] do
      env = %Envelope{body: {:item_vanished, %ItemVanished{ground_id: 42, reason: reason}}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{body: {:item_vanished, %ItemVanished{ground_id: 42, reason: ^reason}}}} =
               Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "pickup_item_request round-trips through envelope oneof" do
    env = %Envelope{body: {:pickup_item_request, %PickupItemRequest{ground_id: 42}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:pickup_item_request, %PickupItemRequest{ground_id: 42}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "pickup_result round-trips every result through envelope oneof" do
    for result <- [:OK, :TOO_FAR, :OVERWEIGHT, :INVENTORY_FULL, :GONE] do
      env = %Envelope{body: {:pickup_result, %PickupResult{ground_id: 42, result: result}}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{body: {:pickup_result, %PickupResult{ground_id: 42, result: ^result}}}} =
               Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "npc_interact round-trips every response arm through envelope oneof" do
    for response <- [
          {:continue, true},
          {:choice, 3},
          {:number, -42},
          {:input, "Loki"},
          {:cancel, true}
        ] do
      env = %Envelope{body: {:npc_interact, %NpcInteract{npc_id: 7, response: response}}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok, %Envelope{body: {:npc_interact, %NpcInteract{npc_id: 7, response: ^response}}}} =
               Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "party_create_request round-trips through envelope oneof" do
    env = %Envelope{body: {:party_create_request, %PartyCreateRequest{name: "Valhalla"}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:party_create_request, %PartyCreateRequest{name: "Valhalla"}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_invite_request round-trips through envelope oneof" do
    env = %Envelope{
      body: {:party_invite_request, %PartyInviteRequest{target_char_id: 10_001, target_name: ""}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:party_invite_request, %PartyInviteRequest{target_char_id: 10_001}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_invite_notify round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:party_invite_notify,
         %PartyInviteNotify{party_id: 1, party_name: "Valhalla", inviter_name: "Sigrid"}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:party_invite_notify,
                 %PartyInviteNotify{party_id: 1, party_name: "Valhalla", inviter_name: "Sigrid"}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_invite_response round-trips through envelope oneof" do
    env = %Envelope{
      body: {:party_invite_response, %PartyInviteResponse{party_id: 1, accept: true}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:party_invite_response, %PartyInviteResponse{party_id: 1, accept: true}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_leave_request round-trips through envelope oneof" do
    env = %Envelope{body: {:party_leave_request, %PartyLeaveRequest{}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:party_leave_request, %PartyLeaveRequest{}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_kick_request round-trips through envelope oneof" do
    env = %Envelope{body: {:party_kick_request, %PartyKickRequest{target_char_id: 10_001}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{body: {:party_kick_request, %PartyKickRequest{target_char_id: 10_001}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_options_request round-trips through envelope oneof" do
    env = %Envelope{body: {:party_options_request, %PartyOptionsRequest{exp_share: true}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:party_options_request, %PartyOptionsRequest{exp_share: true}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_leader_request round-trips through envelope oneof" do
    env = %Envelope{body: {:party_leader_request, %PartyLeaderRequest{target_char_id: 10_002}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{body: {:party_leader_request, %PartyLeaderRequest{target_char_id: 10_002}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_action_result round-trips every PartyError value through envelope oneof" do
    for error <- [
          :NONE,
          :NAME_TAKEN,
          :ALREADY_IN_PARTY,
          :PARTY_FULL,
          :NOT_LEADER,
          :LEVEL_RANGE,
          :SAME_ACCOUNT,
          :TARGET_OFFLINE,
          :NOT_MEMBER,
          :NOT_SAME_MAP
        ] do
      env = %Envelope{
        body:
          {:party_action_result,
           %PartyActionResult{action: "create", success: false, error: error}}
      }

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{
                body:
                  {:party_action_result,
                   %PartyActionResult{action: "create", success: false, error: ^error}}
              }} = Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "party_member round-trips exact state values" do
    member = %PartyMember{
      char_id: 10_001,
      name: "Sigrid",
      base_level: 99,
      online: true,
      map: "prontera",
      job_id: 4_012,
      hp: 4_000_000_000,
      max_hp: 5_000_000_000,
      sp: 6_000_000_000,
      max_sp: 7_000_000_000,
      ap: 150,
      max_ap: 200
    }

    {:ok, iodata, _size} = PartyMember.encode(member)

    assert {:ok, ^member} = PartyMember.decode(IO.iodata_to_binary(iodata))
  end

  test "party_member_update round-trips a complete member" do
    update = %PartyMemberUpdate{
      party_id: 42,
      member: %PartyMember{char_id: 10_001, name: "Sigrid", hp: 999, max_hp: 1_000}
    }

    {:ok, iodata, _size} = PartyMemberUpdate.encode(update)

    assert {:ok, ^update} = PartyMemberUpdate.decode(IO.iodata_to_binary(iodata))
  end

  test "party_member_update round-trips through envelope oneof" do
    update = %PartyMemberUpdate{
      party_id: 42,
      member: %PartyMember{char_id: 10_001, name: "Sigrid", hp: 999, max_hp: 1_000}
    }

    env = %Envelope{seq: 7, body: {:party_member_update, update}}
    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{seq: 7, body: {:party_member_update, ^update}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_info with nested members round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:party_info,
         %PartyInfo{
           party_id: 1,
           name: "Valhalla",
           leader_char_id: 10_001,
           exp_share: true,
           members: [
             %PartyMember{
               char_id: 10_001,
               name: "Sigrid",
               base_level: 99,
               online: true,
               map: "prontera"
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:party_info,
                 %PartyInfo{
                   party_id: 1,
                   name: "Valhalla",
                   leader_char_id: 10_001,
                   exp_share: true,
                   members: [
                     %PartyMember{
                       char_id: 10_001,
                       name: "Sigrid",
                       base_level: 99,
                       online: true,
                       map: "prontera"
                     }
                   ]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "party_disbanded round-trips through envelope oneof" do
    env = %Envelope{body: {:party_disbanded, %PartyDisbanded{party_id: 1, reason: "leader_left"}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:party_disbanded, %PartyDisbanded{party_id: 1, reason: "leader_left"}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_create_request round-trips through envelope oneof" do
    env = %Envelope{seq: 1, body: {:guild_create_request, %GuildCreateRequest{name: "x"}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{seq: 1, body: {:guild_create_request, %GuildCreateRequest{name: "x"}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_invite_request round-trips through envelope oneof" do
    env = %Envelope{
      body: {:guild_invite_request, %GuildInviteRequest{target_char_id: 10_002, target_name: ""}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:guild_invite_request, %GuildInviteRequest{target_char_id: 10_002}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_invite_response round-trips through envelope oneof" do
    env = %Envelope{
      body: {:guild_invite_response, %GuildInviteResponse{guild_id: 5, accept: true}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:guild_invite_response, %GuildInviteResponse{guild_id: 5, accept: true}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_leave_request round-trips through envelope oneof" do
    env = %Envelope{body: {:guild_leave_request, %GuildLeaveRequest{}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:guild_leave_request, %GuildLeaveRequest{}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_expel_request round-trips through envelope oneof" do
    env = %Envelope{
      body: {:guild_expel_request, %GuildExpelRequest{target_char_id: 10_003, reason: "afk"}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:guild_expel_request, %GuildExpelRequest{target_char_id: 10_003, reason: "afk"}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_position_edit_request round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:guild_position_edit_request,
         %GuildPositionEditRequest{index: 5, name: "Officer", can_invite: true, can_expel: false}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:guild_position_edit_request,
                 %GuildPositionEditRequest{
                   index: 5,
                   name: "Officer",
                   can_invite: true,
                   can_expel: false
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_member_position_request round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:guild_member_position_request,
         %GuildMemberPositionRequest{target_char_id: 10_004, index: 3}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:guild_member_position_request,
                 %GuildMemberPositionRequest{target_char_id: 10_004, index: 3}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_notice_edit_request round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:guild_notice_edit_request, %GuildNoticeEditRequest{subject: "Raid", body: "Tonight"}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:guild_notice_edit_request,
                 %GuildNoticeEditRequest{subject: "Raid", body: "Tonight"}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_emblem_upload_request round-trips raw bytes through envelope oneof" do
    data = <<0x42, 0x4D, 1, 2, 3, 4, 5>>
    env = %Envelope{body: {:guild_emblem_upload_request, %GuildEmblemUploadRequest{data: data}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:guild_emblem_upload_request, %GuildEmblemUploadRequest{data: ^data}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_emblem_request round-trips through envelope oneof" do
    env = %Envelope{body: {:guild_emblem_request, %GuildEmblemRequest{guild_id: 5, emblem_id: 3}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:guild_emblem_request, %GuildEmblemRequest{guild_id: 5, emblem_id: 3}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_action_result round-trips every GuildError value through envelope oneof" do
    for error <- [
          :GUILD_ERR_NONE,
          :GUILD_ERR_NAME_TAKEN,
          :GUILD_ERR_ALREADY_IN_GUILD,
          :GUILD_ERR_GUILD_FULL,
          :GUILD_ERR_NO_PERMISSION,
          :GUILD_ERR_NOT_MEMBER,
          :GUILD_ERR_TARGET_OFFLINE,
          :GUILD_ERR_NO_EMPERIUM,
          :GUILD_ERR_INVALID_EMBLEM,
          :GUILD_ERR_CANNOT_TARGET_MASTER,
          :GUILD_ERR_INVALID_POSITION
        ] do
      env = %Envelope{
        body:
          {:guild_action_result,
           %GuildActionResult{action: "create", success: false, error: error}}
      }

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok,
              %Envelope{
                body:
                  {:guild_action_result,
                   %GuildActionResult{action: "create", success: false, error: ^error}}
              }} = Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "guild_invite_notify round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:guild_invite_notify,
         %GuildInviteNotify{guild_id: 5, guild_name: "Aesir", inviter_name: "Sigrid"}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:guild_invite_notify,
                 %GuildInviteNotify{guild_id: 5, guild_name: "Aesir", inviter_name: "Sigrid"}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_member round-trips exact state values" do
    member = %GuildMember{
      char_id: 10_001,
      name: "Sigrid",
      job_id: 4_012,
      base_level: 99,
      online: true,
      map: "prontera",
      position_index: 0,
      hp: 4_000_000_000,
      max_hp: 5_000_000_000,
      sp: 6_000_000_000,
      max_sp: 7_000_000_000,
      ap: 150,
      max_ap: 200
    }

    {:ok, iodata, _size} = GuildMember.encode(member)

    assert {:ok, ^member} = GuildMember.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_info with nested positions and members round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:guild_info,
         %GuildInfo{
           guild_id: 5,
           name: "Aesir",
           master_char_id: 10_001,
           emblem_id: 2,
           notice_subject: "Raid",
           notice_body: "Tonight at 8",
           positions: [
             %GuildPosition{
               index: 0,
               name: "GuildMaster",
               can_invite: true,
               can_expel: true,
               can_storage: false,
               tax: 0
             }
           ],
           members: [
             %GuildMember{
               char_id: 10_001,
               name: "Sigrid",
               base_level: 99,
               online: true,
               map: "prontera",
               position_index: 0
             }
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:guild_info,
                 %GuildInfo{
                   guild_id: 5,
                   name: "Aesir",
                   master_char_id: 10_001,
                   emblem_id: 2,
                   notice_subject: "Raid",
                   notice_body: "Tonight at 8",
                   positions: [
                     %GuildPosition{
                       index: 0,
                       name: "GuildMaster",
                       can_invite: true,
                       can_expel: true
                     }
                   ],
                   members: [
                     %GuildMember{char_id: 10_001, name: "Sigrid", position_index: 0}
                   ]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_info progression fields round-trip through envelope oneof" do
    info = %GuildInfo{
      guild_id: 5,
      name: "Aesir",
      master_char_id: 10_001,
      level: 12,
      exp: 3_000_000_000,
      next_exp: 14_400_000,
      skill_points: 2,
      skills: [
        %GuildSkillEntry{skill_id: 10_004, level: 3, max_level: 10},
        %GuildSkillEntry{skill_id: 10_000, level: 1, max_level: 1}
      ]
    }

    env = %Envelope{seq: 3, body: {:guild_info, info}}
    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{seq: 3, body: {:guild_info, ^info}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_skill_up_request round-trips through envelope oneof" do
    env = %Envelope{
      seq: 4,
      body: {:guild_skill_up_request, %GuildSkillUpRequest{skill_id: 10_004}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              seq: 4,
              body: {:guild_skill_up_request, %GuildSkillUpRequest{skill_id: 10_004}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_level_up round-trips through envelope oneof" do
    up = %GuildLevelUp{guild_id: 5, level: 13, skill_points: 3}
    env = %Envelope{seq: 5, body: {:guild_level_up, up}}
    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{seq: 5, body: {:guild_level_up, ^up}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_member_update round-trips through envelope oneof" do
    update = %GuildMemberUpdate{
      guild_id: 5,
      member: %GuildMember{
        char_id: 10_001,
        name: "Sigrid",
        position_index: 19,
        hp: 999,
        max_hp: 1_000
      }
    }

    env = %Envelope{seq: 7, body: {:guild_member_update, update}}
    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{seq: 7, body: {:guild_member_update, ^update}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_emblem_changed round-trips through envelope oneof" do
    env = %Envelope{body: {:guild_emblem_changed, %GuildEmblemChanged{guild_id: 5, emblem_id: 3}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:guild_emblem_changed, %GuildEmblemChanged{guild_id: 5, emblem_id: 3}}
            }} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_emblem_data round-trips raw bytes through envelope oneof" do
    data = <<0x42, 0x4D, 9, 8, 7, 6>>

    env = %Envelope{
      body: {:guild_emblem_data, %GuildEmblemData{guild_id: 5, emblem_id: 3, data: data}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:guild_emblem_data, %GuildEmblemData{guild_id: 5, emblem_id: 3, data: ^data}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "guild_disbanded round-trips through envelope oneof" do
    env = %Envelope{body: {:guild_disbanded, %GuildDisbanded{guild_id: 5, reason: "master_left"}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:guild_disbanded, %GuildDisbanded{guild_id: 5, reason: "master_left"}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "unit_spawn carries guild identity fields through envelope oneof" do
    env = %Envelope{
      body: {:unit_spawn, %UnitSpawn{gid: 10_001, guild_id: 5, guild_name: "Aesir", emblem_id: 3}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:unit_spawn,
                 %UnitSpawn{gid: 10_001, guild_id: 5, guild_name: "Aesir", emblem_id: 3}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "storage_opened with nested items round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:storage_opened,
         %StorageOpened{
           capacity: 600,
           items: [
             %InventoryItem{index: 0, nameid: 501, type: 0, amount: 10, identified: true}
           ]
         }}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:storage_opened,
                 %StorageOpened{
                   capacity: 600,
                   items: [%InventoryItem{index: 0, nameid: 501, amount: 10, identified: true}]
                 }}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "storage_deposit_request round-trips through envelope oneof" do
    env = %Envelope{
      body: {:storage_deposit_request, %StorageDepositRequest{inventory_index: 3, amount: 10}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:storage_deposit_request, %StorageDepositRequest{inventory_index: 3, amount: 10}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "storage_withdraw_request round-trips through envelope oneof" do
    env = %Envelope{
      body: {:storage_withdraw_request, %StorageWithdrawRequest{storage_index: 4, amount: 5}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body:
                {:storage_withdraw_request, %StorageWithdrawRequest{storage_index: 4, amount: 5}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "storage_close_request round-trips through envelope oneof" do
    env = %Envelope{body: {:storage_close_request, %StorageCloseRequest{}}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{body: {:storage_close_request, %StorageCloseRequest{}}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "storage_item_added with cards round-trips through envelope oneof" do
    env = %Envelope{
      body:
        {:storage_item_added,
         %StorageItemAdded{
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
                {:storage_item_added,
                 %StorageItemAdded{
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

  test "storage_item_removed round-trips through envelope oneof" do
    env = %Envelope{
      body: {:storage_item_removed, %StorageItemRemoved{index: 5, amount: 1, reason: 0}}
    }

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok,
            %Envelope{
              body: {:storage_item_removed, %StorageItemRemoved{index: 5, amount: 1, reason: 0}}
            }} = Envelope.decode(IO.iodata_to_binary(iodata))
  end

  test "storage_result round-trips every StorageResultCode value through envelope oneof" do
    for result <- [
          :STORAGE_OK,
          :STORAGE_FULL,
          :STORAGE_INVENTORY_FULL,
          :STORAGE_OVERWEIGHT,
          :STORAGE_NOT_STORABLE,
          :STORAGE_ITEM_EQUIPPED,
          :STORAGE_INVALID_AMOUNT,
          :STORAGE_NOT_OPEN,
          :STORAGE_BASIC_SKILL_REQUIRED
        ] do
      env = %Envelope{body: {:storage_result, %StorageResult{result: result}}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok, %Envelope{body: {:storage_result, %StorageResult{result: ^result}}}} =
               Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "announcement round-trips every Style value through envelope oneof" do
    for style <- [:TOP, :CENTER, :LOCAL] do
      announcement = %Announcement{
        text: "Server will restart soon",
        color: 0xFF0000,
        style: style,
        source_name: "GM Odin"
      }

      env = %Envelope{seq: 1, body: {:announcement, announcement}}

      {:ok, iodata, _size} = Envelope.encode(env)

      assert {:ok, %Envelope{seq: 1, body: {:announcement, ^announcement}}} =
               Envelope.decode(IO.iodata_to_binary(iodata))
    end
  end

  test "skill_unit_snapshot round-trips complete group and cell state through envelope oneof" do
    snapshot = %SkillUnitSnapshot{
      server_tick: 4_294_967_296,
      groups: [
        %SkillUnitGroupState{
          group_id: 18_446_744_073_709_551_615,
          skill_id: 87,
          skill_level: 5,
          owner_type: :SKILL_UNIT_OWNER_TYPE_PLAYER,
          owner_id: 42,
          center_x: 150,
          center_y: 100,
          created_tick: 4_294_967_296,
          expires_tick: 4_294_977_296,
          cells: [
            %SkillUnitCellState{
              cell_id: 4_294_967_295,
              x: -10,
              y: 20,
              hp: 1_200,
              max_hp: 1_200,
              flags: 31
            },
            %SkillUnitCellState{
              cell_id: 4_294_967_294,
              x: 11,
              y: -21,
              hp: 0,
              max_hp: 0,
              flags: 16
            }
          ]
        }
      ]
    }

    env = %Envelope{seq: 1, body: {:skill_unit_snapshot, snapshot}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{seq: 1, body: {:skill_unit_snapshot, decoded}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))

    assert decoded == snapshot

    assert decoded.groups |> hd() |> Map.fetch!(:cells) |> Enum.map(& &1.cell_id) ==
             [4_294_967_295, 4_294_967_294]
  end

  test "persistent skill-unit and Estimation oneof fields occupy 155 through 159" do
    fields = Envelope.schema().fields

    assert fields.skill_unit_snapshot.tag == 155
    assert fields.skill_unit_spawn.tag == 156
    assert fields.skill_unit_update.tag == 157
    assert fields.skill_unit_despawn.tag == 158
    assert fields.estimation_result.tag == 159
  end

  test "skill_unit_spawn round-trips complete state through envelope oneof" do
    spawn = %SkillUnitSpawn{
      group: %SkillUnitGroupState{
        group_id: 1,
        skill_id: 85,
        skill_level: 10,
        owner_type: :SKILL_UNIT_OWNER_TYPE_MOB,
        owner_id: 99,
        center_x: 10,
        center_y: -20,
        created_tick: 100,
        expires_tick: 200,
        cells: []
      }
    }

    assert_round_trip(:skill_unit_spawn, spawn)
  end

  test "skill_unit owner types round-trip through envelope oneof" do
    for owner_type <- [
          :SKILL_UNIT_OWNER_TYPE_UNSPECIFIED,
          :SKILL_UNIT_OWNER_TYPE_PLAYER,
          :SKILL_UNIT_OWNER_TYPE_MOB,
          :SKILL_UNIT_OWNER_TYPE_NPC
        ] do
      spawn = %SkillUnitSpawn{
        group: %SkillUnitGroupState{owner_type: owner_type, owner_id: 42}
      }

      assert_round_trip(:skill_unit_spawn, spawn)
    end
  end

  test "skill_unit_update round-trips every reason and signed delta through envelope oneof" do
    for {reason, source_type, source_id} <- [
          {:SKILL_UNIT_UPDATE_REASON_UNSPECIFIED, :SKILL_UNIT_OWNER_TYPE_UNSPECIFIED, 0},
          {:SKILL_UNIT_UPDATE_REASON_DAMAGE, :SKILL_UNIT_OWNER_TYPE_PLAYER, 42},
          {:SKILL_UNIT_UPDATE_REASON_DECAY, :SKILL_UNIT_OWNER_TYPE_UNSPECIFIED, 0}
        ] do
      update = %SkillUnitUpdate{
        group_id: 18_446_744_073_709_551_615,
        cell_id: 4_294_967_295,
        hp: 900,
        max_hp: 1_200,
        hp_delta: -300,
        source_type: source_type,
        source_id: source_id,
        reason: reason,
        server_tick: 4_294_967_296
      }

      decoded = assert_round_trip(:skill_unit_update, update)
      assert decoded.source_type == source_type
      assert decoded.source_id == source_id
    end
  end

  test "skill_unit_despawn round-trips every reason and repeated cell IDs through envelope oneof" do
    for reason <- [
          :SKILL_UNIT_DESPAWN_REASON_UNSPECIFIED,
          :SKILL_UNIT_DESPAWN_REASON_EXPIRED,
          :SKILL_UNIT_DESPAWN_REASON_DESTROYED,
          :SKILL_UNIT_DESPAWN_REASON_SOURCE_CONSUMED,
          :SKILL_UNIT_DESPAWN_REASON_LIFECYCLE,
          :SKILL_UNIT_DESPAWN_REASON_MAP_SHUTDOWN,
          :SKILL_UNIT_DESPAWN_REASON_LEFT_VIEW,
          :SKILL_UNIT_DESPAWN_REASON_CANCELED
        ] do
      despawn = %SkillUnitDespawn{
        group_id: 18_446_744_073_709_551_615,
        cell_ids: [1, 4_294_967_295],
        reason: reason,
        server_tick: 4_294_967_296
      }

      assert_round_trip(:skill_unit_despawn, despawn)
    end
  end

  test "estimation_result round-trips complete target information through envelope oneof" do
    result = %EstimationResult{
      target_id: 1,
      class_id: 1_001,
      level: 99,
      size: 2,
      hp: 1_000_000,
      def: 250,
      race: 6,
      mdef: 175,
      element: 3,
      water_modifier: 25,
      earth_modifier: -50,
      fire_modifier: 100,
      wind_modifier: 0,
      poison_modifier: 75,
      holy_modifier: -25,
      shadow_modifier: 50,
      ghost_modifier: 125,
      undead_modifier: -100,
      server_tick: 4_294_967_296
    }

    assert_round_trip(:estimation_result, result)
  end

  test "skill_menu round-trips every kind and its entry ids through envelope oneof" do
    for {kind, entry_ids} <- [
          {:SKILLS, [11, 17, 21]},
          {:ITEMS, [12_115, 12_116]},
          {:INVENTORY_SLOTS, [2, 5, 8]}
        ] do
      menu = %SkillMenu{src_skill_id: 380, kind: kind, entry_ids: entry_ids}

      decoded = assert_round_trip(:skill_menu, menu)
      assert decoded.kind == kind
      assert decoded.entry_ids == entry_ids
    end
  end

  test "skill_menu round-trips an empty entry list" do
    assert_round_trip(:skill_menu, %SkillMenu{src_skill_id: 380, kind: :SKILLS, entry_ids: []})
  end

  test "skill_menu_reply round-trips catalyst ids and an empty catalyst list" do
    with_catalysts = %SkillMenuReply{
      src_skill_id: 380,
      selected_id: 21,
      extra_ids: [994, 1_000, 1_000]
    }

    decoded = assert_round_trip(:skill_menu_reply, with_catalysts)
    assert decoded.extra_ids == [994, 1_000, 1_000]

    without_catalysts = %SkillMenuReply{src_skill_id: 380, selected_id: 21, extra_ids: []}
    decoded = assert_round_trip(:skill_menu_reply, without_catalysts)
    assert decoded.extra_ids == []
  end

  test "production_result round-trips successful and failed craft outcomes" do
    for success <- [true, false] do
      result = %ProductionResult{success: success, item_id: 1_105}
      assert assert_round_trip(:production_result, result) == result
    end
  end

  test "mount_request round-trips through envelope oneof" do
    assert_round_trip(:mount_request, %MountRequest{mount: true})
    assert_round_trip(:mount_request, %MountRequest{mount: false})
  end

  test "mount_result round-trips every result code through envelope oneof" do
    for result <- [
          :MOUNT_OK,
          :MOUNT_SKILL_NOT_LEARNED,
          :MOUNT_ALREADY_MOUNTED,
          :MOUNT_NOT_MOUNTED,
          :MOUNT_DEAD
        ] do
      assert_round_trip(:mount_result, %MountResult{result: result})
    end
  end

  defp complete_homunculus_ai_config do
    %HomunculusAiConfig{
      stance: :HOMUNCULUS_AI_STANCE_AGGRESSIVE,
      leash_distance: 14,
      join_owner_target: true,
      retaliate: true,
      avoid_bosses: true,
      allowed_mob_class_ids: [1_001, 1_002],
      denied_mob_class_ids: [1_003],
      auto_feed: true,
      auto_feed_threshold: 75,
      auto_cast_sp_reserve_percent: 100,
      skills: [
        %HomunculusAiSkillConfig{
          skill_id: 8_001,
          mode: :HOMUNCULUS_AI_SKILL_MODE_AUTO,
          priority: 100,
          self_hp_threshold: %HomunculusHpThreshold{percent: 25},
          owner_hp_threshold: %HomunculusHpThreshold{percent: 50},
          target_hp_range: %HomunculusHpRange{min_percent: 10, max_percent: 90}
        },
        %HomunculusAiSkillConfig{
          skill_id: 8_002,
          mode: :HOMUNCULUS_AI_SKILL_MODE_MANUAL,
          priority: 1
        }
      ]
    }
  end

  defp complete_homunculus_private_state do
    %HomunculusPrivateState{
      durable_id: 9_223_372_036_854_775_807,
      world_gid: 4_294_967_295,
      name: "Hildr",
      rename_eligible: true,
      species_id: 6_009,
      evolved: true,
      appearance_id: 6_017,
      lifecycle: :HOMUNCULUS_LIFECYCLE_ACTIVE,
      activity: :HOMUNCULUS_ACTIVITY_CASTING,
      current_target_id: 77,
      level: 99,
      exp: 9_223_372_036_854_775_807,
      next_exp: 9_223_372_036_854_775_807,
      skill_points: 33,
      hp: 12_345,
      max_hp: 12_345,
      sp: 1_234,
      max_sp: 1_234,
      stats: %HomunculusDisplayedStats{
        str: 99,
        agi: 98,
        vit: 97,
        int: 96,
        dex: 95,
        luk: 94,
        atk: 500,
        matk: 450,
        def: 300,
        mdef: 250,
        hit: 400,
        flee: 350,
        critical: 42,
        aspd: 190
      },
      hunger: 100,
      intimacy_hundredths: 100_000,
      intimacy_grade: :HOMUNCULUS_INTIMACY_GRADE_LOYAL,
      food_item_id: 5_189,
      active_remaining_ms: 1_800_000,
      skills: [
        %HomunculusSkillMetadata{
          skill_id: 8_001,
          level: 5,
          max_level: 5,
          learnable: true,
          intimacy_required_hundredths: 91_100
        }
      ],
      cooldowns: [%HomunculusCooldown{skill_id: 8_001, remaining_ms: 140_000}],
      ai_config: complete_homunculus_ai_config()
    }
  end

  defp decode(message) do
    {:ok, decoded} = message.__struct__.decode(encode(message))
    decoded
  end

  defp encode(message) do
    {:ok, iodata, _size} = message.__struct__.encode(message)
    IO.iodata_to_binary(iodata)
  end

  defp assert_round_trip(tag, message) do
    env = %Envelope{seq: 1, body: {tag, message}}

    {:ok, iodata, _size} = Envelope.encode(env)

    assert {:ok, %Envelope{seq: 1, body: {^tag, decoded}}} =
             Envelope.decode(IO.iodata_to_binary(iodata))

    assert decoded == message
    decoded
  end
end
