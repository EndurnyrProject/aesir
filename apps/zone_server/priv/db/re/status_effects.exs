%{
  # Stone/Petrification - Progressive effect with two phases
  sc_stone: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    phases: %{
      wait: %{
        duration: 5000,
        modifiers: %{
          mdef: 25,
          movement_speed: -50
        },
        next: :stone
      },
      stone: %{
        modifiers: %{
          element: :earth1,
          def: -50,
          mdef: 25
        },
        flags: [:no_move, :no_attack, :no_skill, :no_magic],
        on_damage: %{
          condition: %{element: :earth},
          action: :remove_self
        }
      }
    },
    calc_flags: [:def_ele, :def, :mdef, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Freeze - Frozen state with defense penalties
  sc_freeze: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    modifiers: %{
      # Water element level 1
      def_ele: 10,
      # -100% physical defense
      def_rate: -100,
      # -50% magic defense
      mdef_rate: -50
    },
    flags: [:no_move, :no_attack, :no_skill],
    on_apply: [
      %{type: :remove_status, targets: [:sc_aeterna]}
    ],
    calc_flags: [:def_ele, :def, :mdef],
    conflicts_with: [:sc_aeterna],
    prevented_by: [
      :sc_refresh,
      :sc_inspiration,
      :sc_warmer,
      :sc_freeze,
      :sc_burning,
      :sc_protection
    ]
  },

  # Stun - Complete action prevention
  sc_stun: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Sleep - Character is asleep, removed on damage
  sc_sleep: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    on_damage: %{
      action: :remove_self
    },
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_sleep, :sc_protection]
  },

  # Poison - DoT with defense reduction
  sc_poison: %{
    properties: [:debuff, :damage_over_time],
    modifiers: %{
      def2: -25
    },
    tick: %{
      interval: 1000,
      actions: [
        %{
          type: :damage,
          formula: "(max_hp / 100 + 7) * (1 + 0.1 * val1)",
          element: :neutral,
          min: 1,
          ignore_def: true
        }
      ]
    },
    on_apply: [
      %{type: :remove_status, targets: [:sc_concentrate, :sc_truesight]},
      %{type: :notify_client, packet: :sc_poison_icon}
    ],
    calc_flags: [:def],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon]
  },

  # Curse - LUK reduction and ATK penalty
  sc_curse: %{
    properties: [:debuff],
    modifiers: %{
      # Set LUK to 0
      luk: -999,
      # -25% base ATK
      batk_rate: -25,
      # -25% weapon ATK
      watk_rate: -25,
      movement_speed: -10
    },
    calc_flags: [:luk, :batk, :watk, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_curse, :sc_protection]
  },

  # Silence - Prevents casting
  sc_silence: %{
    properties: [:debuff, :prevents_skills],
    flags: [:no_magic],
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Confusion - Random movement
  sc_confusion: %{
    properties: [:debuff],
    flags: [:confused_movement],
    on_apply: [
      %{type: :notify_client, packet: :sc_confusion_icon}
    ],
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Blind - HIT and FLEE reduction
  sc_blind: %{
    properties: [:debuff],
    modifiers: %{
      hit: -25,
      flee: -25
    },
    calc_flags: [:hit, :flee],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Bleeding - DoT with SP drain
  sc_bleeding: %{
    properties: [:debuff, :damage_over_time],
    modifiers: %{
      # No HP regeneration
      hp_regen: -100,
      # No SP regeneration
      sp_regen: -100
    },
    tick: %{
      interval: 10000,
      actions: [
        %{
          type: :damage,
          formula: "200 + val1 * 10",
          element: :neutral,
          min: 1
        },
        %{
          type: :damage,
          formula: "val1 * 2",
          damage_type: :sp,
          min: 1
        }
      ]
    },
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Arcane Charge - Buff with charge accumulation and explosion
  sc_arcane_charge: %{
    properties: [:buff],
    instance_state: %{charges: 0},
    modifiers: %{
      matk: "state.charges * 10"
    },
    on_damaged: [
      %{type: :increment_state, key: :charges},
      %{type: :notify_client, packet: :update_charges, data: %{charges: "state.charges"}},
      %{
        type: :conditional,
        condition: "state.charges >= 3",
        then_actions: [
          %{type: :damage, formula: "caster.int * 2", element: :neutral},
          %{type: :set_state, key: :charges, value: 0},
          %{type: :notify_client, packet: :arcane_explosion}
        ]
      }
    ],
    calc_flags: [:matk]
  },

  # Deadly Poison - DoT with high damage and no HP regeneration
  sc_dpoison: %{
    properties: [:debuff, :damage_over_time],
    modifiers: %{
      # No HP regeneration
      hp_regen: -100,
      # No SP regeneration
      sp_regen: -100,
      # -25% defense reduction
      def_rate: -25
    },
    tick: %{
      interval: 1000,
      actions: [
        %{
          type: :conditional,
          # Ensure HP > 25%
          condition: "hp > max_hp / 4",
          then_actions: [
            %{
              type: :damage,
              # 10% max HP damage per tick
              formula: "max_hp / 10",
              element: :neutral,
              min: 1,
              ignore_def: true
            }
          ]
        }
      ]
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_dpoison_icon}
    ],
    calc_flags: [:def, :regen],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Provoke - ATK/DEF modifier with aggro
  sc_provoke: %{
    properties: [:debuff],
    modifiers: %{
      # ATK increase percentage
      batk_rate: "val2",
      # Weapon ATK increase
      watk_rate: "val2",
      # DEF reduction percentage  
      def_rate: "-val3",
      # VIT DEF reduction
      def2_rate: "-val3",
      # HIT bonus
      hit: "val3"
    },
    on_apply: [
      %{type: :set_state, key: :provoked_by, value: "caster.id"},
      %{type: :notify_client, packet: :sc_provoke_icon}
    ],
    on_remove: [
      %{type: :set_state, key: :provoked_by, value: nil}
    ],
    calc_flags: [:batk, :watk, :def, :def2, :hit],
    end_on_start: [:sc_freeze, :sc_stone, :sc_sleep, :sc_trickdead],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Endure - Hit count based defense with MDEF bonus  
  sc_endure: %{
    properties: [:buff],
    instance_state: %{hits_remaining: 7},
    modifiers: %{
      # MDEF bonus based on skill level
      mdef: "val1",
      # Prevents being knocked back/stunned
      endure: true
    },
    on_damaged: [
      %{
        type: :conditional,
        # val4 = infinite endure flag
        condition: "state.hits_remaining > 0 and not val4",
        then_actions: [
          %{type: :increment_state, key: :hits_remaining, value: -1},
          %{
            type: :conditional,
            condition: "state.hits_remaining <= 0",
            then_actions: [
              %{type: :remove_status, targets: [:sc_endure]}
            ]
          }
        ]
      }
    ],
    calc_flags: [:mdef],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Two-Hand Quicken - ASPD and critical bonus
  sc_twohandquicken: %{
    properties: [:buff],
    modifiers: %{
      # Fixed ASPD bonus
      aspd: "val2",
      # HIT bonus
      hit: "val1 * 2",
      # Critical bonus
      cri: "(2 + val1) * 10"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_twohandquicken_icon}
    ],
    flags: [:require_weapon],
    calc_flags: [:aspd, :hit, :cri],
    conflicts_with: [:sc_decreaseagi],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Concentrate - AGI/DEX boost with defense reduction
  sc_concentrate: %{
    properties: [:buff],
    modifiers: %{
      # AGI increase based on skill level
      agi: "(agi - val3) * val2 / 100",
      # DEX increase based on skill level  
      dex: "(dex - val4) * val2 / 100"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_concentrate_icon},
      %{type: :remove_status, targets: [:sc_poison, :sc_truesight]}
    ],
    calc_flags: [:agi, :dex],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Hiding - Complete invisibility with movement restrictions
  sc_hiding: %{
    properties: [:buff],
    modifiers: %{
      movement_speed:
        "(pc_checkskill(target, rg_tunneldrive) > 0) * (-(120 - 6 * pc_checkskill(target, rg_tunneldrive)))"
    },
    flags: [:hide, :no_pick_item, :no_consume_item, :stop_attacking],
    # Can't move unless Tunnel Drive
    states: [:nomovecond],
    on_apply: [
      %{type: :notify_client, packet: :sc_hiding_icon},
      %{type: :set_state, key: :hidden, value: true}
    ],
    on_remove: [
      %{type: :set_state, key: :hidden, value: false}
    ],
    on_touched: :remove_self,
    on_damaged: :remove_self,
    on_map_change: :remove_self,
    calc_flags: [:speed],
    end_on_start: [:sc_closeconfine, :sc_closeconfine2],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Cloaking - Conditional invisibility with wall requirements
  sc_cloaking: %{
    properties: [:buff],
    modifiers: %{
      # Double critical rate
      cri: "cri",
      # TODO: Complex ternary operators and cloaking_wall_check() not supported by FormulaCompiler
      # Original: "cloaking_wall_check() ? (val1 >= 10 ? -25 : -(3 * val1 - 3)) : (val1 < 3 ? -300 : -(30 - 3 * val1))"
      # For now, use simplified formula without wall check
      # If val1 >= 10: -25, if val1 < 3: -300, else: -(30 - 3*val1)
      movement_speed:
        "(val1 >= 10) * (-25) + (val1 < 10 and val1 >= 3) * (-(30 - 3 * val1)) + (val1 < 3) * (-300)"
    },
    flags: [:cloak, :no_pick_item, :stop_attacking],
    on_apply: [
      %{type: :notify_client, packet: :sc_cloaking_icon},
      %{type: :set_state, key: :cloaked, value: true}
    ],
    on_remove: [
      %{type: :set_state, key: :cloaked, value: false}
    ],
    on_move: [
      %{
        type: :conditional,
        # TODO: cloaking_wall_check() is an external function not supported by FormulaCompiler
        # For now, disable this check until we implement a callback system
        # Always false - needs proper implementation
        condition: "0",
        then_actions: [
          %{type: :remove_status, targets: [:sc_cloaking]}
        ]
      }
    ],
    on_touched: :remove_self,
    on_damaged: :remove_self,
    on_map_warp: :remove_self,
    calc_flags: [:cri, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Enchant Poison - Weapon element change with poison chance
  sc_encpoison: %{
    properties: [:buff],
    modifiers: %{
      atk_ele: :poison
    },
    # Poison chance in 1/10000 rate
    instance_state: %{poison_chance: "250 + 50 * val1"},
    on_attack: [
      %{
        type: :conditional,
        condition: "rand() < state.poison_chance",
        then_actions: [
          %{
            type: :apply_status,
            status: :sc_poison,
            target: :enemy,
            duration: "skill_get_time2(:as_enchantpoison, val1)"
          }
        ]
      }
    ],
    on_apply: [
      %{type: :notify_client, packet: :sc_encpoison_icon}
    ],
    on_unequip_weapon: :remove_self,
    calc_flags: [:atk_ele],
    end_on_start: [
      :sc_aspersio,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Poison React - Damage boost and counter-attack on poison damage
  sc_poisonreact: %{
    properties: [:buff],
    instance_state: %{counter_remaining: "val1 / 2", boost_mode: false},
    on_poison_damage: [
      %{
        type: :conditional,
        condition: "state.counter_remaining > 0 and not state.boost_mode",
        then_actions: [
          %{type: :set_state, key: :boost_mode, value: true},
          %{type: :increment_state, key: :counter_remaining, value: -1},
          %{
            type: :conditional,
            condition: "state.counter_remaining <= 0",
            then_actions: [
              %{type: :remove_status, targets: [:sc_poisonreact]}
            ]
          }
        ]
      }
    ],
    on_attack: [
      %{
        type: :conditional,
        condition: "state.boost_mode",
        then_actions: [
          %{
            type: :modify_stat,
            stat: :atk_rate,
            value: "30 * pc_checkskill(caster, :as_poisonreact)"
          },
          %{type: :set_state, key: :boost_mode, value: false},
          %{
            type: :apply_status,
            status: :sc_poison,
            target: :enemy,
            chance: 50,
            duration: "skill_get_time2(:as_poisonreact, val1)"
          },
          %{type: :remove_status, targets: [:sc_poisonreact]}
        ]
      }
    ],
    on_attacked_by_poison_element: [
      %{
        type: :conditional,
        condition: "state.counter_remaining > 0 and not state.boost_mode",
        then_actions: [
          %{type: :set_state, key: :boost_mode, value: true}
        ]
      }
    ],
    calc_flags: [:atk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Quagmire - AGI/DEX reduction and removes speed buffs
  sc_quagmire: %{
    properties: [:debuff],
    modifiers: %{
      agi: "-val2",
      dex: "-val2",
      # ASPD penalty
      aspd: "val2",
      # Movement speed penalty
      movement_speed: 50
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_quagmire_icon},
      %{
        type: :remove_status,
        targets: [
          :sc_loud,
          :sc_concentrate,
          :sc_truesight,
          :sc_windwalk,
          :sc_magneticfield,
          :sc_cartboost,
          :sc_gn_cartboost,
          :sc_increaseagi,
          :sc_adrenaline,
          :sc_adrenaline2,
          :sc_spearquicken,
          :sc_twohandquicken,
          :sc_onehand,
          :sc_merc_quicken,
          :sc_acceleration
        ]
      }
    ],
    calc_flags: [:agi, :dex, :aspd, :speed],
    conflicts_with: [:sc_speedup1],
    prevented_by: [:sc_refresh, :sc_inspiration]
  }
}
