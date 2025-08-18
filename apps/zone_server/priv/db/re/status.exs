[
  %{
    :status => :dpoison,
    :duration_lookup => :npc_poison,
    :calc_flags => [
      :def,
      :def2,
      :regen
    ],
    :opt2 => [:dpoison],
    :flags => [
      :sendoption,
      :bossresist
    ],
    :fail => [
      :refresh,
      :inspiration
    ]
  },
  %{
    :status => :provoke,
    :icon => :efst_provoke,
    :duration_lookup => :sm_provoke,
    :calc_flags => [
      :def,
      :def2,
      :batk,
      :watk
    ],
    :flags => [
      :bossresist,
      :debuff,
      :nosaveinfinite,
      :removeonhermode
    ],
    :end_on_start => [
      :freeze,
      :stone,
      :sleep,
      :trickdead
    ]
  },
  %{
    :status => :endure,
    :icon => :efst_endure,
    :duration_lookup => :sm_endure,
    :calc_flags => [
      :mdef,
      :dspd
    ],
    :flags => [
      :noremoveondead,
      :nosaveinfinite
    ]
  },
  %{
    :status => :twohandquicken,
    :icon => :efst_twohandquicken,
    :duration_lookup => :kn_twohandquicken,
    :calc_flags => [
      :aspd,
      :hit,
      :cri
    ],
    :opt3 => [:quicken],
    :flags => [
      :requireweapon,
      :removeonhermode
    ],
    :fail => [:decreaseagi]
  },
  %{
    :status => :concentrate,
    :icon => :efst_concentration,
    :duration_lookup => :ac_concentration,
    :calc_flags => [
      :agi,
      :dex
    ],
    :flags => [
      :failedmado,
      :removeonhermode
    ],
    :fail => [:quagmire]
  },
  %{
    :status => :hiding,
    :icon => :efst_hiding,
    :duration_lookup => :tf_hiding,
    :states => [
      :nomovecond,
      :nopickitem,
      :noconsumeitem
    ],
    :calc_flags => [:speed],
    :options => [:hide],
    :flags => [
      :ontouch,
      :stopattacking,
      :removeondamaged,
      :removeonchangemap,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :end_on_start => [
      :closeconfine,
      :closeconfine2
    ]
  },
  %{
    :status => :cloaking,
    :icon => :efst_cloaking,
    :duration_lookup => :as_cloaking,
    :states => [:nopickitem],
    :calc_flags => [
      :cri,
      :speed
    ],
    :options => [:cloak],
    :flags => [
      :ontouch,
      :stopattacking,
      :removeondamaged,
      :removeonmapwarp,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :encpoison,
    :icon => :efst_enchantpoison,
    :duration_lookup => :as_enchantpoison,
    :calc_flags => [:atk_ele],
    :flags => [
      :removeonunequipweapon,
      :removeonhermode
    ],
    :end_on_start => [
      :aspersio,
      :fireweapon,
      :waterweapon,
      :windweapon,
      :earthweapon,
      :shadowweapon,
      :ghostweapon
    ]
  },
  %{
    :status => :poisonreact,
    :icon => :efst_poisonreact,
    :duration_lookup => :as_poisonreact,
    :flags => [:removeonhermode]
  },
  %{
    :status => :quagmire,
    :icon => :efst_quagmire,
    :duration_lookup => :wz_quagmire,
    :calc_flags => [
      :agi,
      :dex,
      :aspd,
      :speed
    ],
    :flags => [
      :nosave,
      :noclearance,
      :debuff,
      :removeonhermode
    ],
    :fail => [:speedup1],
    :end_on_start => [
      :loud,
      :concentrate,
      :truesight,
      :windwalk,
      :magneticfield,
      :cartboost,
      :gn_cartboost,
      :increaseagi,
      :adrenaline,
      :adrenaline2,
      :spearquicken,
      :twohandquicken,
      :onehand,
      :merc_quicken,
      :acceleration
    ]
  },
  %{
    :status => :angelus,
    :icon => :efst_angelus,
    :duration_lookup => :al_angelus,
    :calc_flags => [
      :def2,
      :maxhp
    ],
    :opt2 => [:angelus],
    :flags => [
      :sendoption,
      :removeonhermode
    ]
  },
  %{
    :status => :blessing,
    :icon => :efst_blessing,
    :duration_lookup => :al_blessing,
    :calc_flags => [
      :str,
      :int,
      :dex,
      :hit
    ],
    :flags => [
      :bossresist,
      :taekwonangel,
      :removeonhermode
    ]
  },
  %{
    :status => :signumcrucis,
    :icon => :efst_crucis,
    :duration_lookup => :al_crucis,
    :calc_flags => [:def],
    :flags => [:debuff],
    :fail => [:signumcrucis]
  },
  %{
    :status => :increaseagi,
    :icon => :efst_inc_agi,
    :duration_lookup => :al_incagi,
    :calc_flags => [
      :agi,
      :speed,
      :aspd
    ],
    :flags => [
      :failedmado,
      :taekwonangel,
      :removeonhermode
    ],
    :fail => [:quagmire],
    :end_on_start => [
      :decreaseagi,
      :adoramus
    ]
  },
  %{
    :status => :decreaseagi,
    :icon => :efst_dec_agi,
    :duration_lookup => :al_decagi,
    :calc_flags => [
      :agi,
      :speed
    ],
    :flags => [
      :bossresist,
      :nosave,
      :debuff,
      :removeonhermode
    ],
    :fail => [:speedup1],
    :end_on_start => [
      :cartboost,
      :gn_cartboost,
      :increaseagi,
      :adrenaline,
      :adrenaline2,
      :spearquicken,
      :twohandquicken,
      :onehand,
      :merc_quicken,
      :acceleration
    ]
  },
  %{
    :status => :slowpoison,
    :icon => :efst_slowpoison,
    :duration_lookup => :pr_slowpoison,
    :calc_flags => [:regen],
    :flags => [
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :impositio,
    :icon => :efst_impositio,
    :duration_lookup => :pr_impositio,
    :calc_flags => [
      :watk,
      :matk
    ],
    :flags => [
      :supernoviceangel,
      :removeonhermode
    ],
    :end_on_start => [:impositio]
  },
  %{
    :status => :suffragium,
    :icon => :efst_suffragium,
    :duration_lookup => :pr_suffragium,
    :flags => [
      :supernoviceangel,
      :removeonhermode
    ]
  },
  %{
    :status => :aspersio,
    :icon => :efst_aspersio,
    :duration_lookup => :pr_aspersio,
    :calc_flags => [:atk_ele],
    :flags => [
      :removeonunequipweapon,
      :removeonhermode
    ],
    :end_on_start => [
      :encpoison,
      :fireweapon,
      :waterweapon,
      :windweapon,
      :earthweapon,
      :shadowweapon,
      :ghostweapon,
      :enchantarms
    ]
  },
  %{
    :status => :benedictio,
    :icon => :efst_benedictio,
    :duration_lookup => :pr_benedictio,
    :calc_flags => [:def_ele],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :kyrie,
    :icon => :efst_kyrie,
    :duration_lookup => :pr_kyrie,
    :flags => [
      :supernoviceangel,
      :removeonhermode
    ]
  },
  %{
    :status => :magnificat,
    :icon => :efst_magnificat,
    :duration_lookup => :pr_magnificat,
    :calc_flags => [:regen],
    :flags => [
      :failedmado,
      :nosave,
      :supernoviceangel,
      :removeonhermode
    ],
    :end_on_start => [:offertorium]
  },
  %{
    :status => :gloria,
    :icon => :efst_gloria,
    :duration_lookup => :pr_gloria,
    :calc_flags => [:luk],
    :flags => [
      :supernoviceangel,
      :removeonhermode
    ]
  },
  %{
    :status => :aeterna,
    :icon => :efst_lexaeterna,
    :duration_lookup => :pr_lexaeterna,
    :flags => [
      :nosave,
      :removeonhermode
    ],
    :fail => [
      :stone,
      :freeze
    ]
  },
  %{
    :status => :adrenaline,
    :icon => :efst_adrenaline,
    :duration_lookup => :bs_adrenaline,
    :calc_flags => [
      :aspd,
      :hit
    ],
    :flags => [
      :madocancel,
      :requireweapon,
      :removeonhermode
    ],
    :fail => [
      :quagmire,
      :decreaseagi
    ]
  },
  %{
    :status => :weaponperfection,
    :icon => :efst_weaponperfect,
    :duration_lookup => :bs_weaponperfect,
    :flags => [
      :madocancel,
      :removeonhermode
    ]
  },
  %{
    :status => :overthrust,
    :icon => :efst_overthrust,
    :duration_lookup => :bs_overthrust,
    :opt3 => [:overthrust],
    :flags => [
      :madocancel,
      :removeonhermode
    ],
    :fail => [:maxoverthrust]
  },
  %{
    :status => :maximizepower,
    :icon => :efst_maximize,
    :duration_lookup => :bs_maximize,
    :calc_flags => [:regen],
    :flags => [
      :madocancel,
      :removeonhermode
    ]
  },
  %{
    :status => :trickdead,
    :icon => :efst_trickdead,
    :duration_lookup => :nv_trickdead,
    :states => [
      :nomove,
      :nopickitem,
      :noconsumeitem,
      :noattack,
      :nointeract
    ],
    :calc_flags => [:regen],
    :flags => [
      :stopwalking,
      :stopattacking,
      :stopcasting,
      :removeondamaged,
      :nosave,
      :noclearance,
      :removeonchangemap,
      :removeonhermode
    ],
    :end_on_start => [:dancing]
  },
  %{
    :status => :loud,
    :icon => :efst_shout,
    :duration_lookup => :mc_loud,
    :calc_flags => [
      :str,
      :batk
    ],
    :flags => [
      :madocancel,
      :removeonhermode
    ]
  },
  %{
    :status => :energycoat,
    :icon => :efst_energycoat,
    :duration_lookup => :mg_energycoat,
    :opt3 => [:energycoat],
    :flags => [:removeonhermode]
  },
  %{
    :status => :brokenarmor,
    :icon => :efst_brokenarmor,
    :duration_lookup => :npc_armorbrake
  },
  %{
    :status => :brokenweapon,
    :icon => :efst_brokenweapon,
    :duration_lookup => :npc_weaponbraker
  },
  %{
    :status => :hallucination,
    :icon => :efst_illusion,
    :duration_lookup => :npc_hallucination,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :debuff,
      :spreadeffect
    ],
    :fail => [:inspiration]
  },
  %{
    :status => :weight50,
    :icon => :efst_weightover50,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :end_on_start => [:weight90]
  },
  %{
    :status => :weight90,
    :icon => :efst_weightover90,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :stopattacking,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :end_on_start => [:weight50]
  },
  %{
    :status => :aspdpotion0,
    :icon => :efst_atthaste_potion1,
    :calc_flags => [:aspd],
    :flags => [
      :noclearance,
      :overlapignorelevel
    ]
  },
  %{
    :status => :aspdpotion1,
    :icon => :efst_atthaste_potion2,
    :calc_flags => [:aspd],
    :flags => [
      :noclearance,
      :overlapignorelevel,
      :removeonhermode
    ]
  },
  %{
    :status => :aspdpotion2,
    :icon => :efst_atthaste_potion3,
    :calc_flags => [:aspd],
    :flags => [
      :overlapignorelevel,
      :removeonhermode
    ]
  },
  %{
    :status => :aspdpotion3,
    :icon => :efst_atthaste_infinity,
    :calc_flags => [:aspd],
    :flags => [
      :noclearance,
      :overlapignorelevel,
      :removeonhermode
    ]
  },
  %{
    :status => :speedup0,
    :icon => :efst_movhaste_horse,
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bSpeedRate, getstatus(SC_SPEEDUP0, 1);
"
  },
  %{
    :status => :speedup1,
    :icon => :efst_movhaste_potion,
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ],
    :script => "bonus bSpeedRate, getstatus(SC_SPEEDUP1, 1);
"
  },
  %{
    :status => :atkpotion,
    :icon => :efst_plusattackpower,
    :flags => [
      :noremoveondead,
      :noclearance,
      :overlapignorelevel,
      :removeonhermode
    ],
    :script => "bonus bBaseAtk, getstatus(SC_ATKPOTION, 1);  /* TODO: hidden in status window */
"
  },
  %{
    :status => :matkpotion,
    :icon => :efst_plusmagicpower,
    :flags => [
      :noremoveondead,
      :noclearance,
      :overlapignorelevel,
      :removeonhermode
    ],
    :script => "bonus bMatk2, getstatus(SC_MATKPOTION, 1);
"
  },
  %{
    :status => :wedding,
    :states => [:noattack],
    :calc_flags => [:speed],
    :options => [:wedding],
    :flags => [
      :sendlook,
      :stopattacking,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :slowdown,
    :calc_flags => [:speed],
    :flags => [:debuff]
  },
  %{
    :status => :ankle,
    :icon => :efst_anklesnare,
    :duration_lookup => :ht_anklesnare,
    :states => [:nomove],
    :flags => [
      :noclearbuff,
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonchangemap
    ]
  },
  %{
    :status => :keeping,
    :duration_lookup => :npc_keeping,
    :calc_flags => [:def]
  },
  %{
    :status => :barrier,
    :icon => :efst_barrier,
    :duration_lookup => :npc_barrier,
    :flags => [:removeonhermode]
  },
  %{
    :status => :stripweapon,
    :icon => :efst_noequipweapon,
    :duration_lookup => :rg_stripweapon,
    :calc_flags => [:watk],
    :flags => [
      :debuff,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :stripshield,
    :icon => :efst_noequipshield,
    :duration_lookup => :rg_stripshield,
    :calc_flags => [:def],
    :flags => [
      :debuff,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :striparmor,
    :icon => :efst_noequiparmor,
    :duration_lookup => :rg_striparmor,
    :calc_flags => [:vit],
    :flags => [
      :debuff,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :striphelm,
    :icon => :efst_noequiphelm,
    :duration_lookup => :rg_striphelm,
    :calc_flags => [:int],
    :flags => [
      :debuff,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :cp_weapon,
    :icon => :efst_protectweapon,
    :duration_lookup => :am_cp_weapon,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removechemicalprotect,
      :removeonhermode
    ]
  },
  %{
    :status => :cp_shield,
    :icon => :efst_protectshield,
    :duration_lookup => :am_cp_shield,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removechemicalprotect,
      :removeonhermode
    ]
  },
  %{
    :status => :cp_armor,
    :icon => :efst_protectarmor,
    :duration_lookup => :am_cp_armor,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removechemicalprotect,
      :removeonhermode
    ]
  },
  %{
    :status => :cp_helm,
    :icon => :efst_protecthelm,
    :duration_lookup => :am_cp_helm,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removechemicalprotect,
      :removeonhermode
    ]
  },
  %{
    :status => :autoguard,
    :icon => :efst_autoguard,
    :duration_lookup => :cr_autoguard,
    :flags => [
      :noclearance,
      :requireshield,
      :removeonhermode
    ]
  },
  %{
    :status => :reflectshield,
    :icon => :efst_reflectshield,
    :duration_lookup => :cr_reflectshield,
    :flags => [
      :noclearance,
      :requireshield,
      :removeonhermode
    ],
    :end_on_start => [:reflectdamage]
  },
  %{
    :status => :splasher,
    :icon => :efst_splasher,
    :duration_lookup => :as_splasher
  },
  %{
    :status => :providence,
    :icon => :efst_providence,
    :duration_lookup => :cr_providence,
    :calc_flags => [:all],
    :flags => [
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :defender,
    :icon => :efst_defender,
    :duration_lookup => :cr_defender,
    :calc_flags => [
      :speed,
      :aspd
    ],
    :flags => [
      :requireshield,
      :removeonhermode
    ]
  },
  %{
    :status => :magicrod,
    :icon => :efst_magicrod,
    :duration_lookup => :sa_magicrod,
    :flags => [
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :spellbreaker,
    :flags => [:nowarning]
  },
  %{
    :status => :autospell,
    :icon => :efst_autospell,
    :duration_lookup => :sa_autospell,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noremoveondead,
      :noclearance
    ]
  },
  %{
    :status => :sighttrasher,
    :flags => [:nowarning]
  },
  %{
    :status => :autoberserk,
    :icon => :efst_autoberserk,
    :duration_lookup => :sm_autoberserk,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :spearquicken,
    :icon => :efst_spearquicken,
    :duration_lookup => :cr_spearquicken,
    :calc_flags => [
      :aspd,
      :cri,
      :flee
    ],
    :opt3 => [:quicken],
    :flags => [
      :failedmado,
      :requireweapon,
      :removeonhermode
    ],
    :fail => [:quagmire]
  },
  %{
    :status => :autocounter,
    :icon => :efst_autocounter,
    :duration_lookup => :kn_autocounter,
    :states => [
      :noattack,
      :nomove,
      :nodropitem,
      :nointeract
    ]
  },
  %{
    :status => :sight,
    :duration_lookup => :mg_sight,
    :options => [:sight],
    :flags => [
      :sendoption,
      :nodispell,
      :nobanishingbuster,
      :nosave
    ]
  },
  %{
    :status => :safetywall,
    :duration_lookup => :mg_safetywall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :ruwach,
    :duration_lookup => :al_ruwach,
    :options => [:ruwach],
    :flags => [:sendoption]
  },
  %{
    :status => :extremityfist,
    :icon => :efst_extremityfist,
    :duration_lookup => :mo_extremityfist,
    :calc_flags => [:regen],
    :flags => [
      :debuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :explosionspirits,
    :icon => :efst_explosionspirits,
    :duration_lookup => :mo_explosionspirits,
    :calc_flags => [
      :cri,
      :regen
    ],
    :opt3 => [:explosionspirits],
    :flags => [
      :debuff,
      :noclearance,
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :combo,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :overlapignorelevel
    ]
  },
  %{
    :status => :bladestop_wait,
    :duration_lookup => :mo_bladestop,
    :states => [:nomove],
    :flags => [:removeonchangemap]
  },
  %{
    :status => :bladestop,
    :icon => :efst_bladestop,
    :duration_lookup => :mo_bladestop,
    :states => [
      :nomove,
      :nopickitem,
      :nodropitem,
      :noattack,
      :nointeract
    ],
    :opt3 => [:bladestop],
    :flags => [
      :moblosetarget,
      :noclearbuff,
      :nosave,
      :noclearance,
      :removeonchangemap,
      :removeonhermode
    ]
  },
  %{
    :status => :fireweapon,
    :icon => :efst_propertyfire,
    :duration_lookup => :sa_flamelauncher,
    :calc_flags => [:all],
    :flags => [:removeonunequipweapon],
    :end_on_start => [
      :encpoison,
      :aspersio,
      :waterweapon,
      :windweapon,
      :earthweapon,
      :shadowweapon,
      :ghostweapon
    ]
  },
  %{
    :status => :waterweapon,
    :icon => :efst_propertywater,
    :duration_lookup => :sa_frostweapon,
    :calc_flags => [:all],
    :flags => [:removeonunequipweapon],
    :end_on_start => [
      :encpoison,
      :aspersio,
      :fireweapon,
      :windweapon,
      :earthweapon,
      :shadowweapon,
      :ghostweapon
    ]
  },
  %{
    :status => :windweapon,
    :icon => :efst_propertywind,
    :duration_lookup => :sa_lightningloader,
    :calc_flags => [:all],
    :flags => [:removeonunequipweapon],
    :end_on_start => [
      :encpoison,
      :aspersio,
      :fireweapon,
      :waterweapon,
      :earthweapon,
      :shadowweapon,
      :ghostweapon
    ]
  },
  %{
    :status => :earthweapon,
    :icon => :efst_propertyground,
    :duration_lookup => :sa_seismicweapon,
    :calc_flags => [:all],
    :flags => [:removeonunequipweapon],
    :end_on_start => [
      :encpoison,
      :aspersio,
      :fireweapon,
      :waterweapon,
      :windweapon,
      :shadowweapon,
      :ghostweapon
    ]
  },
  %{
    :status => :volcano,
    :icon => :efst_groundmagic,
    :duration_lookup => :sa_volcano,
    :calc_flags => [
      :batk,
      :watk,
      :matk
    ],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :deluge,
    :icon => :efst_groundmagic,
    :duration_lookup => :sa_deluge,
    :calc_flags => [:maxhp],
    :flags => [
      :nosave,
      :noclearance
    ]
  },
  %{
    :status => :violentgale,
    :icon => :efst_groundmagic,
    :duration_lookup => :sa_violentgale,
    :calc_flags => [:flee],
    :flags => [
      :nosave,
      :noclearance
    ]
  },
  %{
    :status => :watk_element,
    :duration_lookup => :ms_magnum,
    :flags => [:nosave],
    :end_on_start => [:watk_element]
  },
  %{
    :status => :armor,
    :duration_lookup => :npc_defender,
    :calc_flags => [:speed]
  },
  %{
    :status => :armor_element_water,
    :icon => :efst_resist_property_water,
    :flags => [
      :nodispell,
      :overlapignorelevel
    ],
    :script => "bonus2 bSubEle,Ele_Water, getstatus(SC_ARMOR_ELEMENT_WATER, 1);
bonus2 bSubEle,Ele_Earth, getstatus(SC_ARMOR_ELEMENT_WATER, 2);
bonus2 bSubEle,Ele_Fire, getstatus(SC_ARMOR_ELEMENT_WATER, 3);
bonus2 bSubEle,Ele_Wind, getstatus(SC_ARMOR_ELEMENT_WATER, 4);
"
  },
  %{
    :status => :nochat,
    :states => [
      :nopickitemcond,
      :nodropitemcond,
      :nochatcond,
      :noconsumeitemcond
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:nochat]
  },
  %{
    :status => :protectexp,
    :icon => :efst_protectexp,
    :duration_lookup => :we_baby,
    :states => [:nodeathpenalty]
  },
  %{
    :status => :aurablade,
    :icon => :efst_aurablade,
    :duration_lookup => :lk_aurablade,
    :opt3 => [:aurablade],
    :flags => [
      :nosave,
      :requireweapon,
      :removeonunequipweapon,
      :removeonhermode
    ]
  },
  %{
    :status => :parrying,
    :icon => :efst_parrying,
    :duration_lookup => :lk_parrying,
    :flags => [
      :nosave,
      :noclearance,
      :requireweapon,
      :removeonhermode
    ]
  },
  %{
    :status => :concentration,
    :icon => :efst_lkconcentration,
    :duration_lookup => :lk_concentration,
    :calc_flags => [
      :hit,
      :def
    ],
    :opt3 => [:quicken],
    :flags => [
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :tensionrelax,
    :icon => :efst_tensionrelax,
    :duration_lookup => :lk_tensionrelax,
    :calc_flags => [:regen],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :berserk,
    :icon => :efst_berserk,
    :duration_lookup => :lk_berserk,
    :states => [
      :nocast,
      :nochat,
      :noequipitem,
      :nounequipitem,
      :noconsumeitem
    ],
    :calc_flags => [:all],
    :opt3 => [:berserk],
    :flags => [:nosave],
    :fail => [
      :saturdaynightfever,
      :_bloodylust
    ]
  },
  %{
    :status => :fury,
    :flags => [:nowarning]
  },
  %{
    :status => :gospel,
    :icon => :efst_gospel,
    :duration_lookup => :pa_gospel,
    :states => [:nomovecond],
    :calc_flags => [
      :speed,
      :aspd
    ],
    :flags => [
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :assumptio,
    :icon => :efst_assumptio2,
    :duration_lookup => :hp_assumptio,
    :calc_flags => [:def],
    :opt3 => [:assumptio],
    :flags => [:removeonhermode],
    :end_on_start => [:kaite]
  },
  %{
    :status => :basilica,
    :icon => :efst_basilica_buff,
    :duration_lookup => :hp_basilica,
    :calc_flags => [:all],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :guildaura,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :magicpower,
    :icon => :efst_magicpower,
    :duration_lookup => :hw_magicpower,
    :calc_flags => [:matk],
    :flags => [
      :nosave,
      :removeonhermode
    ],
    :end_on_start => [:magicpower]
  },
  %{
    :status => :edp,
    :icon => :efst_edp,
    :duration_lookup => :asc_edp,
    :calc_flags => [:watk],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :truesight,
    :icon => :efst_truesight,
    :duration_lookup => :sn_sight,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk,
      :cri,
      :hit
    ],
    :flags => [
      :failedmado,
      :nosave,
      :removeonhermode
    ],
    :fail => [:quagmire]
  },
  %{
    :status => :windwalk,
    :icon => :efst_windwalk,
    :duration_lookup => :sn_windwalk,
    :calc_flags => [
      :flee,
      :speed
    ],
    :flags => [
      :failedmado,
      :nosave,
      :removeonhermode
    ],
    :fail => [:quagmire]
  },
  %{
    :status => :meltdown,
    :icon => :efst_meltdown,
    :duration_lookup => :ws_meltdown,
    :flags => [
      :madocancel,
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :cartboost,
    :icon => :efst_cartboost,
    :duration_lookup => :ws_cartboost,
    :calc_flags => [:speed],
    :flags => [
      :madocancel,
      :noremoveondead,
      :noclearance,
      :nosave,
      :nobanishingbuster,
      :nodispell
    ],
    :fail => [:quagmire],
    :end_return => [:decreaseagi]
  },
  %{
    :status => :chasewalk,
    :icon => :efst_chasewalk,
    :duration_lookup => :st_chasewalk,
    :states => [:nopickitem],
    :calc_flags => [:speed],
    :options => [
      :chasewalk,
      :cloak
    ],
    :flags => [
      :ontouch,
      :stopattacking,
      :removeondamaged,
      :removeonchangemap,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :rejectsword,
    :icon => :efst_swordreject,
    :duration_lookup => :st_rejectsword
  },
  %{
    :status => :marionette,
    :icon => :efst_marionette_master,
    :duration_lookup => :cg_marionette,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :opt3 => [:marionette],
    :flags => [:removeonchangemap],
    :fail => [:marionette]
  },
  %{
    :status => :marionette2,
    :icon => :efst_marionette,
    :duration_lookup => :cg_marionette,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :opt3 => [:marionette],
    :flags => [:removeonchangemap],
    :fail => [:marionette2]
  },
  %{
    :status => :changeundead,
    :icon => :efst_propertyundead,
    :duration_lookup => :npc_changeundead,
    :calc_flags => [:def_ele],
    :opt3 => [:undead],
    :flags => [
      :debuff,
      :noclearance,
      :nosave,
      :removeonhermode
    ],
    :end_on_start => [
      :blessing,
      :increaseagi
    ]
  },
  %{
    :status => :jointbeat,
    :icon => :efst_jointbeat,
    :duration_lookup => :lk_jointbeat,
    :calc_flags => [
      :batk,
      :def2,
      :speed,
      :aspd
    ],
    :flags => [
      :nosave,
      :noclearance,
      :debuff,
      :removeonhermode
    ]
  },
  %{
    :status => :mindbreaker,
    :icon => :efst_mindbreaker,
    :duration_lookup => :pf_mindbreaker,
    :calc_flags => [:all],
    :flags => [
      :nosave,
      :debuff,
      :removeonhermode
    ],
    :end_on_start => [
      :freeze,
      :stone,
      :sleep
    ]
  },
  %{
    :status => :memorize,
    :icon => :efst_memorize,
    :duration_lookup => :pf_memorize,
    :flags => [
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :fogwall,
    :icon => :efst_fogwall,
    :duration_lookup => :pf_fogwall,
    :flags => [
      :bossresist,
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :spiderweb,
    :icon => :efst_spiderweb,
    :duration_lookup => :pf_spiderweb,
    :states => [:nomove],
    :calc_flags => [:flee],
    :flags => [
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :debuff
    ]
  },
  %{
    :status => :devotion,
    :icon => :efst_devotion,
    :duration_lookup => :cr_devotion,
    :flags => [
      :nosave,
      :removeonchangemap,
      :overlapignorelevel,
      :removeonhermode
    ],
    :end_on_end => [
      :autoguard,
      :defender,
      :reflectshield,
      :endure
    ]
  },
  %{
    :status => :sacrifice,
    :duration_lookup => :pa_sacrifice,
    :flags => [:removeonhermode]
  },
  %{
    :status => :steelbody,
    :icon => :efst_steelbody,
    :duration_lookup => :mo_steelbody,
    :states => [:nocast],
    :calc_flags => [
      :def,
      :mdef,
      :aspd,
      :speed
    ],
    :opt3 => [:steelbody],
    :flags => [
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :orcish,
    :duration_lookup => :sa_reverseorcish,
    :options => [:orcish],
    :flags => [
      :debuff,
      :sendoption
    ]
  },
  %{
    :status => :readystorm,
    :icon => :efst_stormkick_on,
    :duration_lookup => :tk_readystorm,
    :flags => [
      :noremoveondead,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :readydown,
    :icon => :efst_downkick_on,
    :duration_lookup => :tk_readydown,
    :flags => [
      :noremoveondead,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :readyturn,
    :icon => :efst_turnkick_on,
    :duration_lookup => :tk_readyturn,
    :flags => [
      :noremoveondead,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :readycounter,
    :icon => :efst_counter_on,
    :duration_lookup => :tk_readycounter,
    :flags => [
      :noremoveondead,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :dodge,
    :icon => :efst_dodge_on,
    :duration_lookup => :tk_dodge,
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :run,
    :icon => :efst_run,
    :duration_lookup => :tk_run,
    :calc_flags => [
      :speed,
      :dspd
    ],
    :flags => [
      :nosave,
      :noclearance,
      :removeonchangemap,
      :removeonhermode
    ]
  },
  %{
    :status => :shadowweapon,
    :icon => :efst_propertydark,
    :duration_lookup => :tk_sevenwind,
    :calc_flags => [:atk_ele],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ],
    :end_on_start => [
      :encpoison,
      :aspersio,
      :fireweapon,
      :waterweapon,
      :windweapon,
      :earthweapon,
      :ghostweapon
    ]
  },
  %{
    :status => :adrenaline2,
    :icon => :efst_adrenaline2,
    :duration_lookup => :bs_adrenaline2,
    :calc_flags => [:aspd],
    :flags => [
      :madocancel,
      :nosave,
      :requireweapon,
      :removeonhermode
    ],
    :fail => [
      :quagmire,
      :decreaseagi
    ]
  },
  %{
    :status => :ghostweapon,
    :icon => :efst_propertytelekinesis,
    :duration_lookup => :tk_sevenwind,
    :calc_flags => [:atk_ele],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ],
    :end_on_start => [
      :encpoison,
      :aspersio,
      :fireweapon,
      :waterweapon,
      :windweapon,
      :earthweapon,
      :shadowweapon
    ]
  },
  %{
    :status => :kaizel,
    :icon => :efst_kaizel,
    :duration_lookup => :sl_kaizel
  },
  %{
    :status => :kaahi,
    :icon => :efst_kaahi,
    :duration_lookup => :sl_kaahi,
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ],
    :end_on_start => [:kaahi]
  },
  %{
    :status => :kaupe,
    :icon => :efst_kaupe,
    :duration_lookup => :sl_kaupe,
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :onehand,
    :icon => :efst_onehandquicken,
    :duration_lookup => :kn_onehand,
    :calc_flags => [:aspd],
    :opt3 => [:quicken],
    :flags => [
      :nosave,
      :noclearance,
      :requireweapon,
      :removeonhermode
    ],
    :fail => [:decreaseagi],
    :end_on_start => [
      :aspdpotion0,
      :aspdpotion1,
      :aspdpotion2,
      :aspdpotion3
    ]
  },
  %{
    :status => :preserve,
    :icon => :efst_preserve,
    :duration_lookup => :st_preserve,
    :flags => [
      :nosave,
      :removeonhermode
    ]
  },
  %{
    :status => :battleorders,
    :icon => :efst_gdskill_battleorder,
    :duration_lookup => :gd_battleorder,
    :calc_flags => [
      :str,
      :int,
      :dex
    ]
  },
  %{
    :status => :regeneration,
    :icon => :efst_gdskill_regeneration,
    :duration_lookup => :gd_regeneration,
    :calc_flags => [:regen],
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :nosaveinfinite
    ]
  },
  %{
    :status => :doublecast,
    :icon => :efst_doublecasting,
    :duration_lookup => :pf_doublecasting,
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :maxoverthrust,
    :icon => :efst_overthrustmax,
    :duration_lookup => :ws_overthrustmax,
    :opt3 => [:overthrust],
    :flags => [
      :madocancel,
      :nosave,
      :removeonunequipweapon,
      :removeonhermode
    ],
    :end_on_start => [:overthrust]
  },
  %{
    :status => :hermode,
    :icon => :efst_hermode,
    :duration_lookup => :cg_hermode
  },
  %{
    :status => :shrink,
    :icon => :efst_cr_shrink,
    :duration_lookup => :cr_shrink,
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :nosave
    ]
  },
  %{
    :status => :sightblaster,
    :icon => :efst_wz_sightblaster,
    :duration_lookup => :wz_sightblaster,
    :options => [:sight],
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :winkcharm,
    :icon => :efst_dc_winkcharm,
    :duration_lookup => :dc_winkcharm,
    :states => [:nocastcond],
    :flags => [
      :removeondamaged,
      :debuff
    ]
  },
  %{
    :status => :closeconfine,
    :icon => :efst_rg_cconfine_m,
    :duration_lookup => :rg_closeconfine,
    :states => [:nomove],
    :calc_flags => [:flee],
    :flags => [
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :noremoveondead,
      :removeonchangemap,
      :bossresist
    ]
  },
  %{
    :status => :closeconfine2,
    :icon => :efst_rg_cconfine_s,
    :duration_lookup => :rg_closeconfine,
    :states => [:nomove],
    :flags => [
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :noremoveondead,
      :removeonchangemap,
      :bossresist
    ],
    :fail => [:closeconfine2]
  },
  %{
    :status => :dancing,
    :icon => :efst_bdplaying,
    :duration_lookup => :bd_encore,
    :states => [:nomovecond],
    :calc_flags => [
      :speed,
      :regen
    ],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonchangemap,
      :requireweapon,
      :overlapignorelevel
    ],
    :end_on_end => [:ensemblefatigue]
  },
  %{
    :status => :elementalchange,
    :icon => :efst_armor_property,
    :duration_lookup => :npc_attrichange,
    :calc_flags => [:def_ele],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :richmankim,
    :icon => :efst_richmankim,
    :duration_lookup => :bd_richmankim,
    :flags => [
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :richmankim,
      :eternalchaos,
      :drumbattle,
      :nibelungen,
      :rokisweil,
      :intoabyss,
      :siegfried
    ]
  },
  %{
    :status => :eternalchaos,
    :icon => :efst_eternalchaos,
    :duration_lookup => :bd_eternalchaos,
    :calc_flags => [
      :def,
      :def2
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :richmankim,
      :eternalchaos,
      :drumbattle,
      :nibelungen,
      :rokisweil,
      :intoabyss,
      :siegfried
    ]
  },
  %{
    :status => :drumbattle,
    :icon => :efst_drumbattlefield,
    :duration_lookup => :bd_drumbattlefield,
    :calc_flags => [:def],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :richmankim,
      :eternalchaos,
      :drumbattle,
      :nibelungen,
      :rokisweil,
      :intoabyss,
      :siegfried
    ]
  },
  %{
    :status => :nibelungen,
    :icon => :efst_ringnibelungen,
    :duration_lookup => :bd_ringnibelungen,
    :calc_flags => [:all],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :richmankim,
      :eternalchaos,
      :drumbattle,
      :nibelungen,
      :rokisweil,
      :intoabyss,
      :siegfried
    ]
  },
  %{
    :status => :rokisweil,
    :icon => :efst_rokisweil,
    :duration_lookup => :bd_rokisweil,
    :states => [:nocast],
    :flags => [
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :richmankim,
      :eternalchaos,
      :drumbattle,
      :nibelungen,
      :rokisweil,
      :intoabyss,
      :siegfried
    ]
  },
  %{
    :status => :intoabyss,
    :icon => :efst_intoabyss,
    :duration_lookup => :bd_intoabyss,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :richmankim,
      :eternalchaos,
      :drumbattle,
      :nibelungen,
      :rokisweil,
      :intoabyss,
      :siegfried
    ]
  },
  %{
    :status => :siegfried,
    :icon => :efst_siegfried,
    :duration_lookup => :bd_siegfried,
    :calc_flags => [:all],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :richmankim,
      :eternalchaos,
      :drumbattle,
      :nibelungen,
      :rokisweil,
      :intoabyss,
      :siegfried
    ]
  },
  %{
    :status => :whistle,
    :icon => :efst_whistle,
    :duration_lookup => :ba_whistle,
    :calc_flags => [
      :flee,
      :flee2
    ],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :whistle,
      :assncros,
      :poembragi,
      :appleidun
    ]
  },
  %{
    :status => :assncros,
    :icon => :efst_assassincross,
    :duration_lookup => :ba_assassincross,
    :calc_flags => [:aspd],
    :flags => [
      :noremoveondead,
      :failedmado,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:quagmire],
    :end_on_start => [
      :whistle,
      :assncros,
      :poembragi,
      :appleidun
    ]
  },
  %{
    :status => :poembragi,
    :icon => :efst_poembragi,
    :duration_lookup => :ba_poembragi,
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :whistle,
      :assncros,
      :poembragi,
      :appleidun
    ]
  },
  %{
    :status => :appleidun,
    :icon => :efst_appleidun,
    :duration_lookup => :ba_appleidun,
    :calc_flags => [:maxhp],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :whistle,
      :assncros,
      :poembragi,
      :appleidun
    ]
  },
  %{
    :status => :modechange,
    :duration_lookup => :npc_emotion,
    :calc_flags => [:mode]
  },
  %{
    :status => :humming,
    :icon => :efst_humming,
    :duration_lookup => :dc_humming,
    :calc_flags => [:hit],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :dontforgetme,
      :humming,
      :fortune,
      :service4u
    ]
  },
  %{
    :status => :dontforgetme,
    :icon => :efst_dontforgetme,
    :duration_lookup => :dc_dontforgetme,
    :calc_flags => [
      :speed,
      :aspd
    ],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:speedup1],
    :end_on_start => [
      :increaseagi,
      :adrenaline,
      :adrenaline2,
      :spearquicken,
      :twohandquicken,
      :onehand,
      :merc_quicken,
      :acceleration,
      :dontforgetme,
      :humming,
      :fortune,
      :service4u
    ]
  },
  %{
    :status => :fortune,
    :icon => :efst_fortunekiss,
    :duration_lookup => :dc_fortunekiss,
    :calc_flags => [:all],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :dontforgetme,
      :humming,
      :fortune,
      :service4u
    ]
  },
  %{
    :status => :service4u,
    :icon => :efst_serviceforyou,
    :duration_lookup => :dc_serviceforyou,
    :calc_flags => [:all],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :dontforgetme,
      :humming,
      :fortune,
      :service4u
    ]
  },
  %{
    :status => :stop,
    :icon => :efst_stop,
    :duration_lookup => :npc_stop,
    :states => [:nomove],
    :flags => [
      :stopwalking,
      :nosave,
      :noclearance,
      :removeonchangemap,
      :debuff,
      :removeonhermode
    ]
  },
  %{
    :status => :spurt,
    :icon => :efst_strup,
    :duration_lookup => :tk_run,
    :calc_flags => [:str],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode,
      :requirenoweapon
    ]
  },
  %{
    :status => :spirit,
    :icon => :efst_soullink,
    :duration_lookup => :sl_high,
    :calc_flags => [:all],
    :opt3 => [:soullink],
    :flags => [
      :noclearance,
      :nosave,
      :nobanishingbuster,
      :removeonhermode
    ],
    :fail => [
      :soulgolem,
      :soulshadow,
      :soulfalcon,
      :soulfairy
    ]
  },
  %{
    :status => :coma,
    :duration_lookup => :npc_darkblessing,
    :flags => [
      :bossresist,
      :mvpresist
    ]
  },
  %{
    :status => :intravision,
    :icon => :efst_clairvoyance,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incallstatus,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :incstr,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster
    ],
    :script => "bonus bStr, getstatus(SC_INCSTR, 1);
"
  },
  %{
    :status => :incagi,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bAgi, getstatus(SC_INCAGI, 1);
"
  },
  %{
    :status => :incvit,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bVit, getstatus(SC_INCVIT, 1);
"
  },
  %{
    :status => :incint,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bInt, getstatus(SC_INCINT, 1);
"
  },
  %{
    :status => :incdex,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bDex, getstatus(SC_INCDEX, 1);
"
  },
  %{
    :status => :incluk,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bLuk, getstatus(SC_INCLUK, 1);
"
  },
  %{
    :status => :inchit,
    :calc_flags => [:hit],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :inchitrate,
    :calc_flags => [:hit],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incflee,
    :calc_flags => [:flee],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incfleerate,
    :calc_flags => [:flee],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incmhprate,
    :calc_flags => [:maxhp],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incmsprate,
    :calc_flags => [:maxsp],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incatkrate,
    :calc_flags => [
      :batk,
      :watk
    ],
    :opt3 => [:explosionspirits],
    :flags => [
      :sendoption,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incmatkrate,
    :calc_flags => [:all],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incdefrate,
    :calc_flags => [:def],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :strfood,
    :icon => :efst_food_str,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:food_str_cash],
    :script => "bonus bStr, getstatus(SC_STRFOOD, 1);
"
  },
  %{
    :status => :agifood,
    :icon => :efst_food_agi,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:food_agi_cash],
    :script => "bonus bAgi, getstatus(SC_AGIFOOD, 1);
"
  },
  %{
    :status => :vitfood,
    :icon => :efst_food_vit,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:food_vit_cash],
    :script => "bonus bVit, getstatus(SC_VITFOOD, 1);
"
  },
  %{
    :status => :intfood,
    :icon => :efst_food_int,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:food_int_cash],
    :script => "bonus bInt, getstatus(SC_INTFOOD, 1);
"
  },
  %{
    :status => :dexfood,
    :icon => :efst_food_dex,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:food_dex_cash],
    :script => "bonus bDex, getstatus(SC_DEXFOOD, 1);
"
  },
  %{
    :status => :lukfood,
    :icon => :efst_food_luk,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:food_luk_cash],
    :script => "bonus bLuk, getstatus(SC_LUKFOOD, 1);
"
  },
  %{
    :status => :hitfood,
    :icon => :efst_food_basichit,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bHit, getstatus(SC_HITFOOD, 1);
"
  },
  %{
    :status => :fleefood,
    :icon => :efst_food_basicavoidance,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bFlee, getstatus(SC_FLEEFOOD, 1);
"
  },
  %{
    :status => :batkfood,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bBaseAtk, getstatus(SC_BATKFOOD, 1);
"
  },
  %{
    :status => :watkfood,
    :calc_flags => [:watk],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :matkfood,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bMatk, getstatus(SC_MATKFOOD, 1);
"
  },
  %{
    :status => :scresist,
    :duration_lookup => :pa_gospel
  },
  %{
    :status => :xmas,
    :states => [:noattack],
    :options => [:xmas],
    :flags => [
      :sendlook,
      :stopattacking,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :warm,
    :icon => :efst_sg_sun_warm,
    :duration_lookup => :sg_sun_warm,
    :opt3 => [:warm],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonchangemap,
      :removeonmapwarp
    ]
  },
  %{
    :status => :sun_comfort,
    :icon => :efst_sun_comfort,
    :duration_lookup => :sg_sun_comfort,
    :calc_flags => [:def2],
    :flags => [:removeonmapwarp]
  },
  %{
    :status => :moon_comfort,
    :icon => :efst_moon_comfort,
    :duration_lookup => :sg_moon_comfort,
    :calc_flags => [:flee],
    :flags => [:removeonmapwarp]
  },
  %{
    :status => :star_comfort,
    :icon => :efst_star_comfort,
    :duration_lookup => :sg_star_comfort,
    :calc_flags => [:aspd],
    :flags => [:removeonmapwarp]
  },
  %{
    :status => :fusion,
    :duration_lookup => :sg_fusion,
    :calc_flags => [:speed],
    :options => [:flying],
    :flags => [
      :sendoption,
      :noremoveondead
    ],
    :end_on_start => [:spirit]
  },
  %{
    :status => :skillrate_up,
    :duration_lookup => :sg_friend
  },
  %{
    :status => :ske,
    :duration_lookup => :sl_ske,
    :calc_flags => [
      :batk,
      :watk,
      :def,
      :def2
    ],
    :opt3 => [:energycoat]
  },
  %{
    :status => :kaite,
    :icon => :efst_kaite,
    :duration_lookup => :sl_kaite,
    :opt3 => [:kaite],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ],
    :end_on_start => [:assumptio]
  },
  %{
    :status => :swoo,
    :icon => :efst_swoo,
    :duration_lookup => :sl_swoo,
    :calc_flags => [:speed],
    :opt3 => [:overthrust],
    :flags => [:nonplayer]
  },
  %{
    :status => :ska,
    :duration_lookup => :sl_ska,
    :calc_flags => [
      :def2,
      :mdef2
    ],
    :opt3 => [:steelbody],
    :flags => [:nonplayer]
  },
  %{
    :status => :earthscroll,
    :icon => :efst_earthscroll,
    :duration_lookup => :tk_sptime,
    :calc_flags => [
      :def,
      :mdef,
      :aspd
    ],
    :flags => [:noremoveondead]
  },
  %{
    :status => :miracle,
    :icon => :efst_soullink,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :removeonmapwarp,
      :noremoveondead,
      :noclearance
    ]
  },
  %{
    :status => :madnesscancel,
    :icon => :efst_gs_madnesscancel,
    :duration_lookup => :gs_madnesscancel,
    :states => [:nomove],
    :calc_flags => [:aspd],
    :flags => [
      :nodispell,
      :nobanishingbuster
    ],
    :fail => [
      :p_alter,
      :heat_barrel
    ],
    :end_on_start => [:adjustment]
  },
  %{
    :status => :adjustment,
    :icon => :efst_gs_adjustment,
    :duration_lookup => :gs_adjustment,
    :calc_flags => [
      :hit,
      :flee
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster
    ],
    :end_on_start => [:madnesscancel]
  },
  %{
    :status => :increasing,
    :icon => :efst_gs_accuracy,
    :duration_lookup => :gs_increasing,
    :calc_flags => [
      :agi,
      :dex,
      :hit
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :gatlingfever,
    :icon => :efst_gs_gatlingfever,
    :duration_lookup => :gs_gatlingfever,
    :calc_flags => [
      :flee,
      :speed,
      :aspd
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :requireweapon
    ]
  },
  %{
    :status => :tatamigaeshi,
    :duration_lookup => :nj_tatamigaeshi
  },
  %{
    :status => :utsusemi,
    :icon => :efst_nj_utsusemi,
    :duration_lookup => :nj_utsusemi,
    :flags => [
      :nosave,
      :noclearance,
      :nobanishingbuster,
      :nodispell,
      :removeonhermode
    ]
  },
  %{
    :status => :bunsinjyutsu,
    :icon => :efst_nj_bunsinjyutsu,
    :duration_lookup => :nj_bunsinjyutsu,
    :calc_flags => [:dye],
    :opt3 => [:bunsin],
    :flags => [
      :nosave,
      :noclearance,
      :removeonhermode
    ]
  },
  %{
    :status => :kaensin,
    :flags => [:nowarning]
  },
  %{
    :status => :suiton,
    :icon => :efst_nj_suiton,
    :duration_lookup => :nj_suiton,
    :calc_flags => [
      :agi,
      :speed
    ],
    :flags => [
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :noremoveondead,
      :debuff
    ]
  },
  %{
    :status => :nen,
    :icon => :efst_nj_nen,
    :duration_lookup => :nj_nen,
    :calc_flags => [
      :str,
      :int
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :knowledge,
    :duration_lookup => :sg_knowledge,
    :calc_flags => [:all],
    :flags => [:restartonmapwarp]
  },
  %{
    :status => :sma,
    :icon => :efst_sma_ready,
    :duration_lookup => :sl_sma,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :fling,
    :duration_lookup => :gs_fling,
    :calc_flags => [
      :def,
      :def2
    ]
  },
  %{
    :status => :avoid,
    :duration_lookup => :hlif_avoid,
    :calc_flags => [:speed],
    :flags => [
      :nosave,
      :removefromhomonmapwarp
    ]
  },
  %{
    :status => :change,
    :duration_lookup => :hlif_change,
    :calc_flags => [
      :vit,
      :int
    ],
    :flags => [
      :nosave,
      :removefromhomonmapwarp
    ],
    :fail => [:change]
  },
  %{
    :status => :bloodlust,
    :duration_lookup => :hami_bloodlust,
    :calc_flags => [
      :batk,
      :watk
    ],
    :flags => [
      :nosave,
      :removefromhomonmapwarp
    ]
  },
  %{
    :status => :fleet,
    :duration_lookup => :hfli_fleet,
    :calc_flags => [
      :aspd,
      :batk,
      :watk
    ]
  },
  %{
    :status => :speed,
    :duration_lookup => :hfli_speed,
    :calc_flags => [:flee]
  },
  %{
    :status => :defence,
    :duration_lookup => :hami_defence,
    :calc_flags => [
      :def,
      :vit
    ],
    :flags => [
      :nosave,
      :removefromhomonmapwarp
    ]
  },
  %{
    :status => :incaspdrate,
    :calc_flags => [:aspd],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :incflee2,
    :icon => :efst_plusavoidvalue,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bFlee2, getstatus(SC_INCFLEE2, 1);
"
  },
  %{
    :status => :jailed,
    :states => [:nowarp],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :enchantarms,
    :icon => :efst_weaponproperty,
    :duration_lookup => :item_enchantarms,
    :calc_flags => [:atk_ele],
    :flags => [
      :sendval1,
      :overlapignorelevel,
      :removeonunequipweapon,
      :removeonhermode
    ],
    :end_on_start => [
      :enchantarms,
      :aspersio
    ]
  },
  %{
    :status => :magicalattack,
    :duration_lookup => :npc_magicalattack,
    :calc_flags => [:matk]
  },
  %{
    :status => :armorchange,
    :duration_lookup => :npc_stoneskin,
    :calc_flags => [
      :def,
      :mdef
    ]
  },
  %{
    :status => :criticalwound,
    :icon => :efst_criticalwound,
    :duration_lookup => :npc_criticalwound,
    :flags => [
      :debuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :magicmirror,
    :duration_lookup => :npc_magicmirror
  },
  %{
    :status => :slowcast,
    :icon => :efst_slowcast,
    :duration_lookup => :npc_slowcast,
    :flags => [
      :debuff,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :summer,
    :states => [:noattack],
    :options => [:summer],
    :flags => [
      :sendlook,
      :stopattacking,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :expboost,
    :icon => :efst_cash_plusexp,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :itemboost,
    :icon => :efst_cash_receiveitem,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :bossmapinfo,
    :icon => :efst_cash_boss_alarm,
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonmapwarp
    ],
    :fail => [:bossmapinfo]
  },
  %{
    :status => :lifeinsurance,
    :icon => :efst_cash_deathpenalty,
    :states => [:nodeathpenalty],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ]
  },
  %{
    :status => :inccri,
    :icon => :efst_criticalpercent,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bCritical, getstatus(SC_INCCRI, 1);
"
  },
  %{
    :status => :mdef_rate,
    :icon => :efst_protect_mdef,
    :calc_flags => [:mdef],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ]
  },
  %{
    :status => :inchealrate,
    :icon => :efst_healplus,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :pneuma,
    :duration_lookup => :al_pneuma,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :autotrade,
    :flags => [
      :noremoveondead,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :ksprotected,
    :flags => [:nowarning]
  },
  %{
    :status => :armor_resist,
    :flags => [
      :overlapignorelevel,
      :removeonunequiparmor
    ],
    :script => "bonus2 bSubEle,Ele_Water, getstatus(SC_ARMOR_RESIST, 1);
bonus2 bSubEle,Ele_Earth, getstatus(SC_ARMOR_RESIST, 2);
bonus2 bSubEle,Ele_Fire, getstatus(SC_ARMOR_RESIST, 3);
bonus2 bSubEle,Ele_Wind, getstatus(SC_ARMOR_RESIST, 4);
"
  },
  %{
    :status => :spcost_rate,
    :icon => :efst_atker_blood,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bUseSPrate, -getstatus(SC_SPCOST_RATE, 1);
"
  },
  %{
    :status => :commonsc_resist,
    :icon => :efst_target_blood,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_COMMONSC_RESIST, 1);
bonus2 bResEff,Eff_Stun,.@val1;
bonus2 bResEff,Eff_Freeze,.@val1;
bonus2 bResEff,Eff_Stone,.@val1;
bonus2 bResEff,Eff_Curse,.@val1;
bonus2 bResEff,Eff_Poison,.@val1;
bonus2 bResEff,Eff_Silence,.@val1;
bonus2 bResEff,Eff_Blind,.@val1;
bonus2 bResEff,Eff_Sleep,.@val1;
bonus2 bResEff,Eff_Bleeding,.@val1;
bonus2 bResEff,Eff_Confusion,.@val1;
"
  },
  %{
    :status => :sevenwind,
    :duration_lookup => :tk_sevenwind,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ]
  },
  %{
    :status => :def_rate,
    :icon => :efst_protect_def,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ]
  },
  %{
    :status => :walkspeed,
    :calc_flags => [:speed]
  },
  %{
    :status => :merc_fleeup,
    :icon => :efst_mer_flee,
    :calc_flags => [:flee],
    :flags => [
      :bleffect,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :merc_atkup,
    :icon => :efst_mer_atk,
    :calc_flags => [:watk],
    :flags => [
      :bleffect,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :merc_hpup,
    :icon => :efst_mer_hp,
    :calc_flags => [:maxhp],
    :flags => [
      :bleffect,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :merc_spup,
    :icon => :efst_mer_sp,
    :calc_flags => [:maxsp],
    :flags => [
      :bleffect,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :merc_hitup,
    :icon => :efst_mer_hit,
    :calc_flags => [:hit],
    :flags => [
      :bleffect,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :merc_quicken,
    :duration_lookup => :mer_quicken,
    :calc_flags => [:aspd],
    :opt3 => [:quicken],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:decreaseagi]
  },
  %{
    :status => :rebirth,
    :duration_lookup => :npc_rebirth
  },
  %{
    :status => :itemscript,
    :calc_flags => [:all],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :s_lifepotion,
    :icon => :efst_s_lifepotion,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "if (!getstatus(SC_BERSERK)) {
   .@val1 = -getstatus(SC_S_LIFEPOTION, 1);
   .@val2 = getstatus(SC_S_LIFEPOTION, 2) * 1000;
   bonus2 bRegenPercentHP, .@val1, .@val2;
}
"
  },
  %{
    :status => :l_lifepotion,
    :icon => :efst_l_lifepotion,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "if (!getstatus(SC_BERSERK)) {
   .@val1 = -getstatus(SC_L_LIFEPOTION, 1);
   .@val2 = getstatus(SC_L_LIFEPOTION, 2) * 1000;
   bonus2 bRegenPercentHP, .@val1, .@val2;
}
"
  },
  %{
    :status => :jexpboost,
    :icon => :efst_cash_plusonlyjobexp,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :hellpower,
    :icon => :efst_hellpower,
    :duration_lookup => :npc_hellpower,
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :invincible,
    :icon => :efst_invincible,
    :duration_lookup => :npc_invincible,
    :calc_flags => [
      :aspd,
      :speed
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :manu_atk,
    :icon => :efst_manu_atk,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus2 bAddRace2,RC2_MANUK, getstatus(SC_MANU_ATK, 1);
"
  },
  %{
    :status => :manu_def,
    :icon => :efst_manu_def,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus2 bSubRace2,RC2_MANUK, getstatus(SC_MANU_DEF, 1);
"
  },
  %{
    :status => :spl_atk,
    :icon => :efst_spl_atk,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus2 bAddRace2,RC2_SPLENDIDE, getstatus(SC_SPL_ATK, 1);
"
  },
  %{
    :status => :spl_def,
    :icon => :efst_spl_def,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus2 bSubRace2,RC2_SPLENDIDE, getstatus(SC_SPL_DEF, 1);
"
  },
  %{
    :status => :manu_matk,
    :icon => :efst_manu_matk,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus2 bMagicAddRace2,RC2_MANUK, getstatus(SC_MANU_MATK, 1);
"
  },
  %{
    :status => :spl_matk,
    :icon => :efst_spl_matk,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus2 bMagicAddRace2,RC2_SPLENDIDE, getstatus(SC_SPL_MATK, 1);
"
  },
  %{
    :status => :food_str_cash,
    :icon => :efst_food_str_cash,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:strfood],
    :script => "bonus bStr, getstatus(SC_FOOD_STR_CASH, 1);
"
  },
  %{
    :status => :food_agi_cash,
    :icon => :efst_food_agi_cash,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:agifood],
    :script => "bonus bAgi, getstatus(SC_FOOD_AGI_CASH, 1);
"
  },
  %{
    :status => :food_vit_cash,
    :icon => :efst_food_vit_cash,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:vitfood],
    :script => "bonus bVit, getstatus(SC_FOOD_VIT_CASH, 1);
"
  },
  %{
    :status => :food_dex_cash,
    :icon => :efst_food_dex_cash,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:intfood],
    :script => "bonus bDex, getstatus(SC_FOOD_DEX_CASH, 1);
"
  },
  %{
    :status => :food_int_cash,
    :icon => :efst_food_int_cash,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:dexfood],
    :script => "bonus bInt, getstatus(SC_FOOD_INT_CASH, 1);
"
  },
  %{
    :status => :food_luk_cash,
    :icon => :efst_food_luk_cash,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:lukfood],
    :script => "bonus bLuk, getstatus(SC_FOOD_LUK_CASH, 1);
"
  },
  %{
    :status => :fear,
    :duration_lookup => :rk_windcutter,
    :states => [:nomovecond],
    :calc_flags => [
      :flee,
      :hit
    ],
    :flags => [
      :bossresist,
      :stopwalking,
      :debuff
    ],
    :fail => [:inspiration],
    :end_on_start => [:blind]
  },
  %{
    :status => :burning,
    :icon => :efst_burnt,
    :duration_lookup => :rk_dragonbreath,
    :calc_flags => [:mdef],
    :opt1 => :burning,
    :flags => [
      :sendoption,
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :debuff,
      :spreadeffect
    ],
    :min_duration => 10000,
    :fail => [
      :refresh,
      :inspiration,
      :whiteimprison
    ]
  },
  %{
    :status => :freezing,
    :icon => :efst_frostmisty,
    :duration_lookup => :wl_frostmisty,
    :calc_flags => [
      :aspd,
      :speed,
      :def
    ],
    :flags => [
      :bleffect,
      :displaypc,
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :min_duration => 10000,
    :fail => [
      :refresh,
      :inspiration,
      :warmer,
      :freezing
    ]
  },
  %{
    :status => :enchantblade,
    :icon => :efst_enchantblade,
    :duration_lookup => :rk_enchantblade
  },
  %{
    :status => :deathbound,
    :icon => :efst_deathbound,
    :duration_lookup => :rk_deathbound,
    :states => [:nocast],
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :millenniumshield,
    :icon => :efst_reuse_millenniumshield,
    :duration_lookup => :rk_millenniumshield,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :crushstrike,
    :icon => :efst_crushstrike,
    :duration_lookup => :rk_crushstrike,
    :flags => [
      :noclearbuff,
      :nodispell
    ]
  },
  %{
    :status => :refresh,
    :icon => :efst_refresh,
    :duration_lookup => :rk_refresh,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :nosave
    ]
  },
  %{
    :status => :reuse_refresh,
    :icon => :efst_reuse_refresh,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_refresh]
  },
  %{
    :status => :giantgrowth,
    :icon => :efst_giantgrowth,
    :duration_lookup => :rk_giantgrowth,
    :calc_flags => [:str],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :stonehardskin,
    :icon => :efst_stonehardskin,
    :duration_lookup => :rk_stonehardskin,
    :calc_flags => [
      :def,
      :mdef
    ],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noremoveondead,
      :nosave
    ]
  },
  %{
    :status => :vitalityactivation,
    :icon => :efst_vitalityactivation,
    :duration_lookup => :rk_vitalityactivation,
    :calc_flags => [:regen],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :stormblast,
    :duration_lookup => :rk_vitalityactivation,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noremoveondead
    ]
  },
  %{
    :status => :fightingspirit,
    :icon => :efst_fightingspirit,
    :duration_lookup => :rk_fightingspirit,
    :calc_flags => [
      :watk,
      :aspd
    ],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ],
    :end_on_start => [:fightingspirit]
  },
  %{
    :status => :abundance,
    :icon => :efst_abundance,
    :duration_lookup => :rk_abundance,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:abundance]
  },
  %{
    :status => :adoramus,
    :icon => :efst_adoramus,
    :duration_lookup => :ab_adoramus,
    :calc_flags => [
      :agi,
      :speed
    ],
    :flags => [
      :bossresist,
      :debuff
    ],
    :end_on_start => [:decreaseagi]
  },
  %{
    :status => :epiclesis,
    :icon => :efst_epiclesis,
    :duration_lookup => :ab_epiclesis,
    :calc_flags => [:maxhp],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :oratio,
    :icon => :efst_oratio,
    :duration_lookup => :ab_oratio,
    :flags => [
      :bleffect,
      :displaypc,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :laudaagnus,
    :icon => :efst_laudaagnus,
    :duration_lookup => :ab_laudaagnus,
    :calc_flags => [:maxhp],
    :flags => [
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :laudaramus,
    :icon => :efst_laudaramus,
    :duration_lookup => :ab_laudaramus,
    :calc_flags => [:all],
    :flags => [
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :renovatio,
    :icon => :efst_renovatio,
    :duration_lookup => :ab_renovatio,
    :calc_flags => [:regen],
    :flags => [
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :expiatio,
    :icon => :efst_expiatio,
    :duration_lookup => :ab_expiatio,
    :flags => [
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :duplelight,
    :icon => :efst_duplelight,
    :duration_lookup => :ab_duplelight,
    :flags => [
      :displaypc,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :secrament,
    :icon => :efst_ab_secrament,
    :duration_lookup => :ab_secrament,
    :flags => [
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :whiteimprison,
    :duration_lookup => :wl_whiteimprison,
    :states => [
      :nomove,
      :nocast
    ],
    :opt1 => :imprison,
    :flags => [
      :sendoption,
      :bossresist,
      :setstand,
      :stopwalking,
      :stopattacking,
      :stopcasting
    ],
    :end_on_start => [:freezing]
  },
  %{
    :status => :marshofabyss,
    :icon => :efst_marshofabyss,
    :duration_lookup => :wl_marshofabyss,
    :calc_flags => [
      :agi,
      :dex,
      :speed
    ],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff
    ],
    :min_duration => 5000,
    :fail => [:refresh],
    :end_on_start => [
      :increaseagi,
      :windwalk,
      :aspdpotion0,
      :aspdpotion1,
      :aspdpotion2,
      :aspdpotion3
    ]
  },
  %{
    :status => :recognizedspell,
    :icon => :efst_recognizedspell,
    :duration_lookup => :wl_recognizedspell,
    :calc_flags => [:matk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :stasis,
    :icon => :efst_stasis,
    :duration_lookup => :wl_stasis,
    :min_duration => 10000
  },
  %{
    :status => :sphere_1,
    :icon => :efst_summon1,
    :flags => [
      :displaypc,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :sphere_2,
    :icon => :efst_summon2,
    :flags => [
      :displaypc,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :sphere_3,
    :icon => :efst_summon3,
    :flags => [
      :displaypc,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :sphere_4,
    :icon => :efst_summon4,
    :flags => [
      :displaypc,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :sphere_5,
    :icon => :efst_summon5,
    :flags => [
      :displaypc,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :reading_sb,
    :flags => [:nowarning]
  },
  %{
    :status => :freeze_sp,
    :icon => :efst_freeze_sp,
    :flags => [:noclearance]
  },
  %{
    :status => :fearbreeze,
    :icon => :efst_fearbreeze,
    :duration_lookup => :ra_fearbreeze,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonunequipweapon
    ]
  },
  %{
    :status => :electricshocker,
    :icon => :efst_electricshocker,
    :duration_lookup => :ra_electricshocker,
    :states => [:nomove],
    :flags => [
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :nosave,
      :noclearance
    ],
    :fail => [:electricshocker]
  },
  %{
    :status => :wugdash,
    :icon => :efst_wugdash,
    :duration_lookup => :ra_wugdash,
    :calc_flags => [
      :speed,
      :dspd
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonchangemap
    ]
  },
  %{
    :status => :bite,
    :icon => :efst_wugbite,
    :duration_lookup => :ra_wugbite,
    :states => [:nomove],
    :flags => [
      :bossresist,
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :debuff
    ],
    :min_rate => 5000
  },
  %{
    :status => :camouflage,
    :icon => :efst_camouflage,
    :duration_lookup => :ra_camouflage,
    :states => [:nomovecond],
    :calc_flags => [:speed],
    :flags => [
      :displaypc,
      :ontouch,
      :stopattacking,
      :removeondamaged,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonchangemap
    ]
  },
  %{
    :status => :acceleration,
    :icon => :efst_acceleration,
    :duration_lookup => :nc_acceleration,
    :calc_flags => [:speed],
    :flags => [
      :madoendcancel,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :hovering,
    :icon => :efst_hovering,
    :duration_lookup => :nc_hovering,
    :calc_flags => [:speed],
    :flags => [
      :madoendcancel,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :shapeshift,
    :icon => :efst_shapeshift,
    :duration_lookup => :nc_shapeshift,
    :calc_flags => [:def_ele],
    :flags => [
      :madoendcancel,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :infraredscan,
    :icon => :efst_infraredscan,
    :duration_lookup => :nc_infraredscan,
    :calc_flags => [:flee],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :analyze,
    :icon => :efst_analyze,
    :duration_lookup => :nc_analyze,
    :calc_flags => [
      :def,
      :def2,
      :mdef,
      :mdef2
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :magneticfield,
    :icon => :efst_magneticfield,
    :duration_lookup => :nc_magneticfield,
    :states => [:nomove],
    :flags => [
      :madoendcancel,
      :bossresist,
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :debuff
    ],
    :fail => [:hovering]
  },
  %{
    :status => :neutralbarrier,
    :icon => :efst_neutralbarrier,
    :duration_lookup => :nc_neutralbarrier,
    :calc_flags => [
      :def,
      :mdef
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :neutralbarrier_master,
    :icon => :efst_neutralbarrier_master,
    :flags => [
      :madoendcancel,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonchangemap
    ]
  },
  %{
    :status => :stealthfield,
    :icon => :efst_stealthfield,
    :duration_lookup => :nc_stealthfield,
    :calc_flags => [:speed],
    :flags => [
      :displaypc,
      :ontouch,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :stopattacking
    ]
  },
  %{
    :status => :stealthfield_master,
    :icon => :efst_stealthfield_master,
    :calc_flags => [:speed],
    :flags => [
      :madoendcancel,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonchangemap
    ]
  },
  %{
    :status => :overheat,
    :icon => :efst_overheat,
    :flags => [
      :madoendcancel,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :overheat_limitpoint,
    :icon => :efst_overheat_limitpoint,
    :flags => [
      :madoendcancel,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :venomimpress,
    :icon => :efst_venomimpress,
    :duration_lookup => :gc_venomimpress,
    :flags => [
      :bleffect,
      :displaypc,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ]
  },
  %{
    :status => :poisoningweapon,
    :icon => :efst_poisoningweapon,
    :duration_lookup => :gc_poisoningweapon,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval3
    ]
  },
  %{
    :status => :weaponblocking,
    :icon => :efst_weaponblocking,
    :duration_lookup => :gc_weaponblocking,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ]
  },
  %{
    :status => :cloakingexceed,
    :icon => :efst_cloakingexceed,
    :duration_lookup => :gc_cloakingexceed,
    :states => [:nopickitem],
    :calc_flags => [:speed],
    :options => [:cloak],
    :flags => [
      :ontouch,
      :stopattacking,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonmapwarp,
      :sendval3
    ]
  },
  %{
    :status => :hallucinationwalk,
    :icon => :efst_hallucinationwalk,
    :duration_lookup => :gc_hallucinationwalk,
    :calc_flags => [:flee],
    :flags => [
      :displaypc,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval3
    ]
  },
  %{
    :status => :hallucinationwalk_postdelay,
    :icon => :efst_hallucinationwalk_postdelay,
    :duration_lookup => :gc_hallucinationwalk,
    :calc_flags => [
      :speed,
      :aspd
    ],
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :rollingcutter,
    :icon => :efst_rollingcutter,
    :duration_lookup => :gc_rollingcutter,
    :flags => [
      :displaypc,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :toxin,
    :icon => :efst_toxin,
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [:toxin]
  },
  %{
    :status => :paralyse,
    :icon => :efst_paralyse,
    :calc_flags => [
      :flee,
      :speed,
      :aspd
    ],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [
      :refresh,
      :inspiration,
      :toxin,
      :paralyse,
      :venombleed,
      :magicmushroom,
      :deathhurt,
      :pyrexia,
      :oblivioncurse,
      :leechesend
    ]
  },
  %{
    :status => :venombleed,
    :icon => :efst_venombleed,
    :calc_flags => [:maxhp],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [
      :refresh,
      :inspiration,
      :toxin,
      :paralyse,
      :venombleed,
      :magicmushroom,
      :deathhurt,
      :pyrexia,
      :oblivioncurse,
      :leechesend
    ]
  },
  %{
    :status => :magicmushroom,
    :icon => :efst_magicmushroom,
    :calc_flags => [:regen],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [
      :refresh,
      :inspiration,
      :toxin,
      :paralyse,
      :venombleed,
      :magicmushroom,
      :deathhurt,
      :pyrexia,
      :oblivioncurse,
      :leechesend
    ]
  },
  %{
    :status => :deathhurt,
    :icon => :efst_deathhurt,
    :calc_flags => [:regen],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [
      :refresh,
      :inspiration,
      :toxin,
      :paralyse,
      :venombleed,
      :magicmushroom,
      :deathhurt,
      :pyrexia,
      :oblivioncurse,
      :leechesend
    ]
  },
  %{
    :status => :pyrexia,
    :icon => :efst_pyrexia,
    :calc_flags => [:all],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [
      :refresh,
      :inspiration,
      :toxin,
      :paralyse,
      :venombleed,
      :magicmushroom,
      :deathhurt,
      :pyrexia,
      :oblivioncurse,
      :leechesend
    ]
  },
  %{
    :status => :oblivioncurse,
    :icon => :efst_oblivioncurse,
    :states => [:nocastcond],
    :calc_flags => [:regen],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [
      :refresh,
      :inspiration,
      :toxin,
      :paralyse,
      :venombleed,
      :magicmushroom,
      :deathhurt,
      :pyrexia,
      :oblivioncurse,
      :leechesend
    ]
  },
  %{
    :status => :leechesend,
    :icon => :efst_leechesend,
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :debuff,
      :spreadeffect
    ],
    :fail => [
      :refresh,
      :inspiration,
      :toxin,
      :paralyse,
      :venombleed,
      :magicmushroom,
      :deathhurt,
      :pyrexia,
      :oblivioncurse,
      :leechesend
    ]
  },
  %{
    :status => :reflectdamage,
    :icon => :efst_lg_reflectdamage,
    :duration_lookup => :lg_reflectdamage,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :requireshield,
      :nosave
    ],
    :end_on_start => [:reflectshield]
  },
  %{
    :status => :forceofvanguard,
    :icon => :efst_forceofvanguard,
    :duration_lookup => :lg_forceofvanguard,
    :calc_flags => [:maxhp],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval3
    ]
  },
  %{
    :status => :shieldspell_hp,
    :icon => :efst_shieldspell,
    :duration_lookup => :lg_shieldspell,
    :end_on_start => [
      :shieldspell_sp,
      :shieldspell_atk
    ]
  },
  %{
    :status => :shieldspell_sp,
    :icon => :efst_shieldspell,
    :duration_lookup => :lg_shieldspell,
    :end_on_start => [
      :shieldspell_hp,
      :shieldspell_atk
    ]
  },
  %{
    :status => :shieldspell_atk,
    :icon => :efst_shieldspell,
    :duration_lookup => :lg_shieldspell,
    :calc_flags => [
      :watk,
      :matk
    ],
    :end_on_start => [
      :shieldspell_hp,
      :shieldspell_sp
    ]
  },
  %{
    :status => :exeedbreak,
    :icon => :efst_exeedbreak,
    :duration_lookup => :lg_exeedbreak,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonunequipweapon
    ]
  },
  %{
    :status => :prestige,
    :icon => :efst_prestige,
    :duration_lookup => :lg_prestige,
    :calc_flags => [:def],
    :flags => [:sendval2]
  },
  %{
    :status => :banding,
    :icon => :efst_banding,
    :duration_lookup => :lg_banding,
    :calc_flags => [:def],
    :flags => [
      :displaypc,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ],
    :fail => [:banding],
    :end_on_start => [:prestige]
  },
  %{
    :status => :banding_defence,
    :icon => :efst_banding_defence,
    :flags => [:bossresist],
    :fail => [:banding_defence]
  },
  %{
    :status => :earthdrive,
    :icon => :efst_earthdrive,
    :duration_lookup => :lg_earthdrive,
    :flags => [
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :inspiration,
    :icon => :efst_inspiration,
    :duration_lookup => :lg_inspiration,
    :calc_flags => [
      :watk,
      :matk,
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk,
      :hit,
      :maxhp
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :spellfist,
    :icon => :efst_spellfist,
    :duration_lookup => :so_spellfist,
    :flags => [:sendval3]
  },
  %{
    :status => :crystalize,
    :icon => :efst_cold,
    :duration_lookup => :so_diamonddust,
    :states => [
      :nomovecond,
      :nocastcond,
      :noconsumeitem,
      :noattack
    ],
    :flags => [
      :bleffect,
      :displaypc,
      :sendoption,
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :stopattacking,
      :stopwalking,
      :stopcasting,
      :setstand,
      :debuff
    ],
    :fail => [
      :refresh,
      :inspiration,
      :warmer,
      :crystalize
    ]
  },
  %{
    :status => :striking,
    :icon => :efst_striking,
    :duration_lookup => :so_striking,
    :calc_flags => [:all],
    :flags => [:nosave]
  },
  %{
    :status => :warmer,
    :icon => :efst_warmer,
    :duration_lookup => :so_warmer,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :crystalize,
      :freezing,
      :freeze
    ]
  },
  %{
    :status => :vacuum_extreme,
    :icon => :efst_vacuum_extreme,
    :duration_lookup => :so_vacuum_extreme,
    :states => [:nomove],
    :flags => [
      :bossresist,
      :stopwalking,
      :stopattacking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonchangemap,
      :debuff
    ],
    :fail => [
      :hallucinationwalk,
      :hovering,
      :npc_hallucinationwalk,
      :vacuum_extreme
    ]
  },
  %{
    :status => :propertywalk,
    :icon => :efst_propertywalk,
    :duration_lookup => :so_firewalk,
    :flags => [
      :nosave,
      :removeonmapwarp,
      :sendval2
    ]
  },
  %{
    :status => :swingdance,
    :icon => :efst_swing,
    :duration_lookup => :wa_swing_dance,
    :calc_flags => [
      :speed,
      :aspd
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :symphonyoflover,
      :moonlitserenade,
      :rushwindmill,
      :echosong,
      :harmonize
    ]
  },
  %{
    :status => :symphonyoflover,
    :icon => :efst_symphony_love,
    :duration_lookup => :wa_symphony_of_lover,
    :calc_flags => [:mdef],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :swingdance,
      :moonlitserenade,
      :rushwindmill,
      :echosong,
      :harmonize
    ]
  },
  %{
    :status => :moonlitserenade,
    :icon => :efst_moonlit_serenade,
    :duration_lookup => :wa_moonlit_serenade,
    :calc_flags => [:matk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :swingdance,
      :symphonyoflover,
      :rushwindmill,
      :echosong,
      :harmonize
    ]
  },
  %{
    :status => :rushwindmill,
    :icon => :efst_rush_windmill,
    :duration_lookup => :mi_rush_windmill,
    :calc_flags => [
      :watk,
      :speed
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :swingdance,
      :symphonyoflover,
      :moonlitserenade,
      :echosong,
      :harmonize
    ]
  },
  %{
    :status => :echosong,
    :icon => :efst_echosong,
    :duration_lookup => :mi_echosong,
    :calc_flags => [:def],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :swingdance,
      :symphonyoflover,
      :moonlitserenade,
      :rushwindmill,
      :harmonize
    ]
  },
  %{
    :status => :harmonize,
    :icon => :efst_harmonize,
    :duration_lookup => :mi_harmonize,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :end_on_start => [
      :swingdance,
      :symphonyoflover,
      :moonlitserenade,
      :rushwindmill,
      :echosong
    ]
  },
  %{
    :status => :voiceofsiren,
    :icon => :efst_siren,
    :duration_lookup => :wm_voiceofsiren,
    :flags => [
      :bleffect,
      :displaypc,
      :stopattacking
    ],
    :min_duration => 10000,
    :end_on_start => [
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :deepsleep,
    :icon => :efst_deep_sleep,
    :duration_lookup => :wm_lullaby_deepsleep,
    :states => [
      :nocast,
      :nochat,
      :noconsumeitem,
      :nomove,
      :noattack
    ],
    :opt1 => :sleep,
    :flags => [
      :bleffect,
      :displaypc,
      :removeonrefresh,
      :removeonluxanima,
      :bossresist,
      :stopwalking,
      :stopattacking,
      :stopcasting,
      :setstand,
      :removeondamaged,
      :nosave,
      :debuff
    ],
    :min_duration => 5000,
    :fail => [
      :refresh,
      :inspiration,
      :deepsleep
    ],
    :end_on_start => [
      :dancing,
      :voiceofsiren,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :sircleofnature,
    :icon => :efst_sircleofnature,
    :duration_lookup => :wm_sircleofnature,
    :calc_flags => [:regen],
    :end_on_start => [
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :gloomyday,
    :icon => :efst_gloomyday,
    :duration_lookup => :wm_gloomyday,
    :calc_flags => [
      :flee,
      :speed,
      :aspd
    ],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice
    ]
  },
  %{
    :status => :gloomyday_sk,
    :icon => :efst_gloomyday
  },
  %{
    :status => :songofmana,
    :icon => :efst_song_of_mana,
    :duration_lookup => :wm_song_of_mana,
    :calc_flags => [:regen],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :dancewithwug,
    :icon => :efst_dance_with_wug,
    :duration_lookup => :wm_dance_with_wug,
    :calc_flags => [:aspd],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :saturdaynightfever,
    :icon => :efst_saturday_night_fever,
    :duration_lookup => :wm_saturday_night_fever,
    :states => [
      :nocast,
      :nochat,
      :noequipitem,
      :nounequipitem,
      :noconsumeitem
    ],
    :calc_flags => [
      :hit,
      :flee,
      :regen
    ],
    :flags => [:nosave],
    :fail => [
      :berserk,
      :inspiration
    ],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :leradsdew,
    :icon => :efst_lerads_dew,
    :duration_lookup => :wm_lerads_dew,
    :calc_flags => [:maxhp],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:berserk],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :melodyofsink,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :melodyofsink,
    :icon => :efst_melodyofsink,
    :duration_lookup => :wm_melodyofsink,
    :calc_flags => [
      :int,
      :maxsp
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :beyondofwarcry,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :beyondofwarcry,
    :icon => :efst_beyond_of_warcry,
    :duration_lookup => :wm_beyond_of_warcry,
    :calc_flags => [
      :str,
      :maxhp
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :unlimitedhummingvoice,
      :sircleofnature
    ]
  },
  %{
    :status => :unlimitedhummingvoice,
    :icon => :efst_unlimited_humming_voice,
    :duration_lookup => :wm_unlimited_humming_voice,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :voiceofsiren,
      :deepsleep,
      :gloomyday,
      :gloomyday_sk,
      :songofmana,
      :dancewithwug,
      :saturdaynightfever,
      :leradsdew,
      :melodyofsink,
      :beyondofwarcry,
      :sircleofnature
    ]
  },
  %{
    :status => :sitdown_force,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :netherworld,
    :icon => :efst_netherworld,
    :duration_lookup => :wm_poemofnetherworld,
    :states => [:nomove],
    :flags => [
      :bleffect,
      :displaypc,
      :bossresist,
      :stopwalking,
      :debuff
    ],
    :fail => [:netherworld]
  },
  %{
    :status => :crescentelbow,
    :icon => :efst_crescentelbow,
    :duration_lookup => :sr_crescentelbow,
    :flags => [
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ]
  },
  %{
    :status => :cursedcircle_atker,
    :icon => :efst_cursedcircle_atker,
    :duration_lookup => :sr_cursedcircle,
    :states => [
      :nomove,
      :noattack
    ],
    :flags => [
      :displaypc,
      :noclearbuff,
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :stopattacking,
      :removeonchangemap,
      :sendval3
    ]
  },
  %{
    :status => :cursedcircle_target,
    :icon => :efst_cursedcircle_target,
    :duration_lookup => :sr_cursedcircle,
    :states => [
      :nomove,
      :nocast,
      :noattack
    ],
    :flags => [
      :bleffect,
      :displaypc,
      :moblosetarget,
      :noclearbuff,
      :stopwalking,
      :stopattacking,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:cursedcircle_target]
  },
  %{
    :status => :lightningwalk,
    :icon => :efst_lightningwalk,
    :duration_lookup => :sr_lightningwalk,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :raisingdragon,
    :icon => :efst_raisingdragon,
    :duration_lookup => :sr_raisingdragon,
    :calc_flags => [
      :maxhp,
      :maxsp
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :gt_energygain,
    :icon => :efst_gentletouch_energygain,
    :duration_lookup => :sr_gentletouch_energygain,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :gt_change,
    :icon => :efst_gentletouch_change,
    :duration_lookup => :sr_gentletouch_change,
    :calc_flags => [
      :watk,
      :aspd
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:gt_revitalize]
  },
  %{
    :status => :gt_revitalize,
    :icon => :efst_gentletouch_revitalize,
    :duration_lookup => :sr_gentletouch_revitalize,
    :calc_flags => [
      :maxhp,
      :regen
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:gt_change]
  },
  %{
    :status => :gn_cartboost,
    :icon => :efst_gn_cartboost,
    :duration_lookup => :gn_cartboost,
    :calc_flags => [:speed],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [
      :quagmire,
      :dontforgetme
    ],
    :end_return => [:decreaseagi]
  },
  %{
    :status => :thornstrap,
    :icon => :efst_thorns_trap,
    :duration_lookup => :gn_thorns_trap,
    :states => [:nomove],
    :flags => [
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :bloodsucker,
    :icon => :efst_blood_sucker,
    :duration_lookup => :gn_blood_sucker,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :smokepowder,
    :icon => :efst_fire_expansion_smoke_powder,
    :duration_lookup => :gn_fire_expansion_smoke_powder,
    :calc_flags => [:flee],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :teargas,
    :icon => :efst_fire_expansion_tear_gas,
    :duration_lookup => :gn_fire_expansion_tear_gas,
    :calc_flags => [
      :hit,
      :flee
    ],
    :flags => [
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ],
    :end_on_end => [:teargas_sob]
  },
  %{
    :status => :mandragora,
    :icon => :efst_mandragora,
    :duration_lookup => :gn_mandragora,
    :calc_flags => [:int],
    :flags => [
      :removeonrefresh,
      :removeonluxanima,
      :nodispell,
      :nobanishingbuster,
      :debuff
    ],
    :fail => [
      :refresh,
      :inspiration,
      :mandragora
    ]
  },
  %{
    :status => :stomachache,
    :icon => :efst_stomachache,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :dex,
      :int,
      :luk
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :debuff
    ]
  },
  %{
    :status => :mysterious_powder,
    :icon => :efst_mysterious_powder,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :debuff
    ],
    :script => "bonus bMaxHPrate, getstatus(SC_MYSTERIOUS_POWDER, 1);
"
  },
  %{
    :status => :melon_bomb,
    :icon => :efst_melon_bomb,
    :calc_flags => [
      :speed,
      :aspd
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :banana_bomb,
    :icon => :efst_banana_bomb,
    :calc_flags => [:luk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :banana_bomb_sitdown,
    :icon => :efst_banana_bomb_sitdown_postdelay,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :savage_steak,
    :icon => :efst_savage_steak,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bStr, getstatus(SC_SAVAGE_STEAK, 1);
"
  },
  %{
    :status => :cocktail_warg_blood,
    :icon => :efst_cocktail_warg_blood,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bInt, getstatus(SC_COCKTAIL_WARG_BLOOD, 1);
"
  },
  %{
    :status => :minor_bbq,
    :icon => :efst_minor_bbq,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bVit, getstatus(SC_MINOR_BBQ, 1);
"
  },
  %{
    :status => :siroma_ice_tea,
    :icon => :efst_siroma_ice_tea,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bDex, getstatus(SC_SIROMA_ICE_TEA, 1);
"
  },
  %{
    :status => :drocera_herb_steamed,
    :icon => :efst_drocera_herb_steamed,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bAgi, getstatus(SC_DROCERA_HERB_STEAMED, 1);
"
  },
  %{
    :status => :putti_tails_noodles,
    :icon => :efst_putti_tails_noodles,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead
    ],
    :script => "bonus bLuk, getstatus(SC_PUTTI_TAILS_NOODLES, 1);
"
  },
  %{
    :status => :boost500,
    :icon => :efst_boost500,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bAspdRate, getstatus(SC_BOOST500, 1);
"
  },
  %{
    :status => :full_swing_k,
    :icon => :efst_full_swing_k,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bBaseAtk, getstatus(SC_FULL_SWING_K, 1);
"
  },
  %{
    :status => :mana_plus,
    :icon => :efst_mana_plus,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bMatk, getstatus(SC_MANA_PLUS, 1);
"
  },
  %{
    :status => :mustle_m,
    :icon => :efst_mustle_m,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bMaxHPrate, getstatus(SC_MUSTLE_M, 1);
"
  },
  %{
    :status => :life_force_f,
    :icon => :efst_life_force_f,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bMaxSPrate, getstatus(SC_LIFE_FORCE_F, 1);
"
  },
  %{
    :status => :extract_white_potion_z,
    :icon => :efst_extract_white_potion_z,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bHPrecovRate, getstatus(SC_EXTRACT_WHITE_POTION_Z, 1);
"
  },
  %{
    :status => :vitata_500,
    :icon => :efst_vitata_500,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bSPrecovRate,20;
bonus bMaxSPrate,5;
"
  },
  %{
    :status => :extract_salamine_juice,
    :icon => :efst_extract_salamine_juice,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bAspdRate, getstatus(SC_EXTRACT_SALAMINE_JUICE, 1);
"
  },
  %{
    :status => :_reproduce,
    :icon => :efst_reproduce,
    :duration_lookup => :sc_reproduce,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :_autoshadowspell,
    :icon => :efst_autoshadowspell,
    :duration_lookup => :sc_autoshadowspell,
    :calc_flags => [:matk]
  },
  %{
    :status => :_shadowform,
    :icon => :efst_shadowform,
    :duration_lookup => :sc_shadowform,
    :states => [
      :nocast,
      :noconsumeitem,
      :noattack
    ],
    :flags => [
      :displaypc,
      :ontouch,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :removeonchangemap,
      :sendval3
    ]
  },
  %{
    :status => :_bodypaint,
    :icon => :efst_bodypaint,
    :duration_lookup => :sc_bodypaint,
    :calc_flags => [:aspd],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :spreadeffect
    ],
    :fail => [:inspiration]
  },
  %{
    :status => :_invisibility,
    :icon => :efst_invisibility,
    :duration_lookup => :sc_invisibility,
    :states => [
      :nocast,
      :noconsumeitem
    ],
    :calc_flags => [
      :aspd,
      :cri,
      :atk_ele
    ],
    :options => [:cloak],
    :flags => [
      :ontouch,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ],
    :fail => [:_invisibility]
  },
  %{
    :status => :_deadlyinfect,
    :icon => :efst_deadlyinfect,
    :duration_lookup => :sc_deadlyinfect,
    :flags => [
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :_enervation,
    :icon => :efst_enervation,
    :duration_lookup => :sc_enervation,
    :calc_flags => [
      :batk,
      :watk
    ],
    :flags => [
      :bossresist,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ],
    :fail => [
      :inspiration,
      :_enervation
    ]
  },
  %{
    :status => :_groomy,
    :icon => :efst_groomy,
    :duration_lookup => :sc_groomy,
    :calc_flags => [
      :aspd,
      :hit
    ],
    :flags => [
      :bossresist,
      :nobanishingbuster,
      :noclearance,
      :sendval3
    ],
    :fail => [
      :inspiration,
      :_groomy
    ]
  },
  %{
    :status => :_ignorance,
    :icon => :efst_ignorance,
    :duration_lookup => :sc_ignorance,
    :states => [:nocast],
    :flags => [
      :bossresist,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [
      :inspiration,
      :_ignorance
    ]
  },
  %{
    :status => :_laziness,
    :icon => :efst_laziness,
    :duration_lookup => :sc_laziness,
    :calc_flags => [
      :flee,
      :speed
    ],
    :flags => [
      :bossresist,
      :nobanishingbuster,
      :noclearance,
      :sendval3
    ],
    :fail => [
      :inspiration,
      :_laziness
    ]
  },
  %{
    :status => :_unlucky,
    :icon => :efst_unlucky,
    :duration_lookup => :sc_unlucky,
    :calc_flags => [
      :cri,
      :flee2
    ],
    :flags => [
      :bossresist,
      :nobanishingbuster,
      :noclearance,
      :sendval3
    ],
    :fail => [
      :inspiration,
      :_unlucky
    ]
  },
  %{
    :status => :_weakness,
    :icon => :efst_weakness,
    :duration_lookup => :sc_weakness,
    :calc_flags => [:maxhp],
    :flags => [
      :bossresist,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ],
    :fail => [
      :inspiration,
      :_weakness
    ]
  },
  %{
    :status => :_stripaccessory,
    :icon => :efst_stripaccessary,
    :duration_lookup => :sc_stripaccessary,
    :calc_flags => [
      :dex,
      :int,
      :luk
    ],
    :flags => [
      :debuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :_manhole,
    :icon => :efst_manhole,
    :duration_lookup => :sc_manhole,
    :states => [
      :noattack,
      :nomove,
      :nocast,
      :noconsumeitem,
      :nointeract
    ],
    :flags => [
      :bleffect,
      :displaypc,
      :moblosetarget,
      :noclearbuff,
      :stopwalking,
      :stopattacking,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonchangemap
    ]
  },
  %{
    :status => :_bloodylust,
    :icon => :efst_bloodylust,
    :duration_lookup => :sc_bloodylust,
    :states => [
      :nocast,
      :nounequipitem
    ],
    :calc_flags => [
      :def,
      :def2,
      :batk,
      :watk
    ],
    :flags => [
      :debuff,
      :nosave
    ]
  },
  %{
    :status => :circle_of_fire,
    :icon => :efst_circle_of_fire,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :circle_of_fire_option,
    :icon => :efst_circle_of_fire_option,
    :duration_lookup => :el_circle_of_fire,
    :calc_flags => [:all],
    :flags => [
      :removeelementaloption,
      :sendval2
    ]
  },
  %{
    :status => :fire_cloak,
    :icon => :efst_fire_cloak,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :fire_cloak_option,
    :icon => :efst_fire_cloak_option,
    :duration_lookup => :el_fire_cloak,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :water_screen,
    :icon => :efst_water_screen,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :water_screen_option,
    :icon => :efst_water_screen_option,
    :duration_lookup => :el_water_screen,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :water_drop,
    :icon => :efst_water_drop,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :water_drop_option,
    :icon => :efst_water_drop_option,
    :duration_lookup => :el_water_drop,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :water_barrier,
    :icon => :efst_water_barrier,
    :duration_lookup => :el_water_barrier,
    :calc_flags => [
      :watk,
      :flee
    ],
    :flags => [
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :wind_step,
    :icon => :efst_wind_step,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :wind_step_option,
    :icon => :efst_wind_step_option,
    :duration_lookup => :el_wind_step,
    :calc_flags => [
      :speed,
      :flee
    ],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :wind_curtain,
    :icon => :efst_wind_curtain,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :wind_curtain_option,
    :icon => :efst_wind_curtain_option,
    :duration_lookup => :el_wind_curtain,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :zephyr,
    :icon => :efst_zephyr,
    :duration_lookup => :el_zephyr,
    :calc_flags => [:flee],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :solid_skin,
    :icon => :efst_solid_skin,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :solid_skin_option,
    :icon => :efst_solid_skin_option,
    :duration_lookup => :el_solid_skin,
    :calc_flags => [
      :def,
      :maxhp
    ],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :stone_shield,
    :icon => :efst_stone_shield,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :stone_shield_option,
    :icon => :efst_stone_shield_option,
    :duration_lookup => :el_stone_shield,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :power_of_gaia,
    :icon => :efst_power_of_gaia,
    :duration_lookup => :el_power_of_gaia,
    :calc_flags => [
      :maxhp,
      :def,
      :speed
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :noremoveondead
    ]
  },
  %{
    :status => :pyrotechnic,
    :icon => :efst_pyrotechnic,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :pyrotechnic_option,
    :icon => :efst_pyrotechnic_option,
    :duration_lookup => :el_pyrotechnic,
    :calc_flags => [:watk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :heater,
    :icon => :efst_heater,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :heater_option,
    :icon => :efst_heater_option,
    :duration_lookup => :el_heater,
    :calc_flags => [:watk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :tropic,
    :icon => :efst_tropic,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :tropic_option,
    :icon => :efst_tropic_option,
    :duration_lookup => :el_tropic,
    :calc_flags => [:watk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption
    ]
  },
  %{
    :status => :aquaplay,
    :icon => :efst_aquaplay,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :aquaplay_option,
    :icon => :efst_aquaplay_option,
    :duration_lookup => :el_aquaplay,
    :calc_flags => [:matk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :cooler,
    :icon => :efst_cooler,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :cooler_option,
    :icon => :efst_cooler_option,
    :duration_lookup => :el_cooler,
    :calc_flags => [:matk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :chilly_air,
    :icon => :efst_chilly_air,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :chilly_air_option,
    :icon => :efst_chilly_air_option,
    :duration_lookup => :el_chilly_air,
    :calc_flags => [:matk],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval2
    ]
  },
  %{
    :status => :gust,
    :icon => :efst_gust,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :gust_option,
    :icon => :efst_gust_option,
    :duration_lookup => :el_gust,
    :calc_flags => [:aspd],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval2
    ]
  },
  %{
    :status => :blast,
    :icon => :efst_blast,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :blast_option,
    :icon => :efst_blast_option,
    :duration_lookup => :el_blast,
    :calc_flags => [:aspd],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :wild_storm,
    :icon => :efst_wild_storm,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :wild_storm_option,
    :icon => :efst_wild_storm_option,
    :duration_lookup => :el_wild_storm,
    :calc_flags => [:aspd],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval2
    ]
  },
  %{
    :status => :petrology,
    :icon => :efst_petrology,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :petrology_option,
    :icon => :efst_petrology_option,
    :duration_lookup => :el_petrology,
    :calc_flags => [:maxhp],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :cursed_soil,
    :icon => :efst_cursed_soil,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :cursed_soil_option,
    :icon => :efst_cursed_soil_option,
    :duration_lookup => :el_cursed_soil,
    :calc_flags => [:maxhp],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval3
    ]
  },
  %{
    :status => :upheaval,
    :icon => :efst_upheaval,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :upheaval_option,
    :icon => :efst_upheaval_option,
    :duration_lookup => :el_upheaval,
    :calc_flags => [:maxhp],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption,
      :sendval2
    ]
  },
  %{
    :status => :tidal_weapon,
    :icon => :efst_tidal_weapon,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeelementaloption
    ]
  },
  %{
    :status => :tidal_weapon_option,
    :icon => :efst_tidal_weapon_option,
    :duration_lookup => :el_tidal_weapon,
    :calc_flags => [:all],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :nosave,
      :removeelementaloption
    ]
  },
  %{
    :status => :rock_crusher,
    :icon => :efst_rock_crusher,
    :duration_lookup => :el_rock_crusher,
    :calc_flags => [:def],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :rock_crusher_atk,
    :icon => :efst_rock_crusher_atk,
    :duration_lookup => :el_rock_crusher_atk,
    :calc_flags => [:speed],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :leadership,
    :duration_lookup => :gd_leadership,
    :calc_flags => [:str],
    :flags => [
      :noclearbuff,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :glorywounds,
    :duration_lookup => :gd_glorywounds,
    :calc_flags => [:vit],
    :flags => [
      :noclearbuff,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :soulcold,
    :duration_lookup => :gd_soulcold,
    :calc_flags => [:agi],
    :flags => [
      :noclearbuff,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :hawkeyes,
    :duration_lookup => :gd_hawkeyes,
    :calc_flags => [:dex],
    :flags => [
      :noclearbuff,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :odins_power,
    :icon => :efst_odins_power,
    :duration_lookup => :all_odins_power,
    :calc_flags => [
      :watk,
      :matk,
      :mdef,
      :def
    ]
  },
  %{
    :status => :raid,
    :icon => :efst_raid,
    :duration_lookup => :rg_raid,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :fire_insignia,
    :icon => :efst_fire_insignia,
    :duration_lookup => :so_fire_insignia,
    :calc_flags => [
      :matk,
      :watk,
      :atk_ele,
      :regen
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :water_insignia,
    :icon => :efst_water_insignia,
    :duration_lookup => :so_fire_insignia,
    :calc_flags => [
      :matk,
      :watk,
      :atk_ele,
      :regen
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :wind_insignia,
    :icon => :efst_wind_insignia,
    :duration_lookup => :so_water_insignia,
    :calc_flags => [
      :matk,
      :watk,
      :aspd,
      :atk_ele,
      :regen
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :earth_insignia,
    :icon => :efst_earth_insignia,
    :duration_lookup => :so_wind_insignia,
    :calc_flags => [
      :mdef,
      :def,
      :maxhp,
      :maxsp,
      :matk,
      :watk,
      :atk_ele,
      :regen
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave
    ]
  },
  %{
    :status => :push_cart,
    :icon => :efst_on_push_cart,
    :calc_flags => [:speed],
    :flags => [
      :displaypc,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1,
      :overlapignorelevel,
      :noforcedend
    ]
  },
  %{
    :status => :spellbook1,
    :icon => :efst_spellbook1,
    :flags => [:noclearance]
  },
  %{
    :status => :spellbook2,
    :icon => :efst_spellbook2,
    :flags => [:noclearance]
  },
  %{
    :status => :spellbook3,
    :icon => :efst_spellbook3,
    :flags => [:noclearance]
  },
  %{
    :status => :spellbook4,
    :icon => :efst_spellbook4,
    :flags => [:noclearance]
  },
  %{
    :status => :spellbook5,
    :icon => :efst_spellbook5,
    :flags => [:noclearance]
  },
  %{
    :status => :spellbook6,
    :icon => :efst_spellbook6,
    :flags => [:noclearance]
  },
  %{
    :status => :maxspellbook,
    :icon => :efst_spellbook7,
    :flags => [:noclearance]
  },
  %{
    :status => :incmhp,
    :calc_flags => [:maxhp],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :incmsp,
    :calc_flags => [:maxsp],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :partyflee,
    :icon => :efst_partyflee,
    :duration_lookup => :all_partyflee,
    :flags => [
      :noclearance,
      :nobanishingbuster
    ]
  },
  %{
    :status => :meikyousisui,
    :icon => :efst_meikyousisui,
    :duration_lookup => :ko_meikyousisui,
    :states => [:nomove],
    :flags => [
      :stopwalking,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :jyumonjikiri,
    :icon => :efst_ko_jyumonjikiri,
    :duration_lookup => :ko_jyumonjikiri,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :kyougaku,
    :icon => :efst_kyougaku,
    :duration_lookup => :ko_kyougaku,
    :states => [
      :nomove,
      :noequipitem,
      :nounequipitem
    ],
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :flags => [
      :stopwalking,
      :nosave,
      :debuff
    ]
  },
  %{
    :status => :izayoi,
    :icon => :efst_izayoi,
    :duration_lookup => :ko_izayoi,
    :calc_flags => [:matk]
  },
  %{
    :status => :zenkai,
    :icon => :efst_zenkai,
    :duration_lookup => :ko_zenkai
  },
  %{
    :status => :kagehumi,
    :icon => :efst_kg_kagehumi,
    :duration_lookup => :kg_kagehumi,
    :states => [
      :nomove,
      :noconsumeitem
    ]
  },
  %{
    :status => :kyomu,
    :icon => :efst_kyomu,
    :duration_lookup => :kg_kyomu
  },
  %{
    :status => :kagemusya,
    :icon => :efst_kagemusya,
    :duration_lookup => :kg_kagemusya
  },
  %{
    :status => :zangetsu,
    :icon => :efst_zangetsu,
    :duration_lookup => :ob_zangetsu,
    :calc_flags => [
      :matk,
      :batk
    ]
  },
  %{
    :status => :gensou,
    :icon => :efst_gensou,
    :duration_lookup => :ob_oborogensou
  },
  %{
    :status => :akaitsuki,
    :icon => :efst_akaitsuki,
    :duration_lookup => :ob_akaitsuki,
    :flags => [
      :bleffect,
      :displaypc,
      :debuff
    ]
  },
  %{
    :status => :style_change,
    :duration_lookup => :mh_style_change,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ]
  },
  %{
    :status => :tinder_breaker,
    :icon => :efst_tinder_breaker_postdelay,
    :duration_lookup => :mh_tinder_breaker,
    :calc_flags => [:flee],
    :flags => [
      :nosave,
      :removeonchangemap
    ]
  },
  %{
    :status => :tinder_breaker2,
    :icon => :efst_tinder_breaker,
    :duration_lookup => :mh_tinder_breaker,
    :calc_flags => [:flee],
    :flags => [
      :nosave,
      :removeonchangemap
    ],
    :fail => [:tinder_breaker2]
  },
  %{
    :status => :cbc,
    :icon => :efst_cbc,
    :duration_lookup => :mh_cbc,
    :calc_flags => [:flee],
    :flags => [:nosave]
  },
  %{
    :status => :eqc,
    :icon => :efst_eqc,
    :duration_lookup => :mh_eqc,
    :calc_flags => [
      :def2,
      :maxhp
    ],
    :flags => [:nosave],
    :end_on_start => [:tinder_breaker2]
  },
  %{
    :status => :goldene_ferse,
    :icon => :efst_goldene_ferse,
    :duration_lookup => :mh_goldene_ferse,
    :calc_flags => [
      :aspd,
      :flee
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:angriffs_modus]
  },
  %{
    :status => :angriffs_modus,
    :icon => :efst_angriffs_modus,
    :duration_lookup => :mh_angriffs_modus,
    :calc_flags => [
      :batk,
      :def,
      :flee,
      :maxhp
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [:goldene_ferse]
  },
  %{
    :status => :overed_boost,
    :icon => :efst_overed_boost,
    :duration_lookup => :mh_overed_boost,
    :calc_flags => [
      :flee,
      :aspd,
      :def
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:overed_boost]
  },
  %{
    :status => :light_of_regene,
    :icon => :efst_light_of_regene,
    :duration_lookup => :mh_light_of_regene,
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :ash,
    :icon => :efst_volcanic_ash,
    :duration_lookup => :mh_volcanic_ash,
    :calc_flags => [
      :def,
      :def2,
      :hit,
      :batk,
      :flee
    ]
  },
  %{
    :status => :granitic_armor,
    :icon => :efst_granitic_armor,
    :duration_lookup => :mh_granitic_armor
  },
  %{
    :status => :magma_flow,
    :icon => :efst_magma_flow,
    :duration_lookup => :mh_magma_flow
  },
  %{
    :status => :pyroclastic,
    :icon => :efst_pyroclastic,
    :duration_lookup => :mh_pyroclastic,
    :calc_flags => [
      :batk,
      :watk
    ]
  },
  %{
    :status => :paralysis,
    :icon => :efst_needle_of_paralyze,
    :duration_lookup => :mh_needle_of_paralyze,
    :states => [:nomove],
    :calc_flags => [:def2],
    :flags => [
      :bossresist,
      :stopwalking,
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :pain_killer,
    :icon => :efst_pain_killer,
    :duration_lookup => :mh_pain_killer,
    :flags => [
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :hanbok,
    :states => [:noattack],
    :options => [:hanbok],
    :flags => [
      :sendlook,
      :stopattacking,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :defset,
    :icon => :efst_set_num_def,
    :calc_flags => [:def],
    :fail => [:defset]
  },
  %{
    :status => :mdefset,
    :icon => :efst_set_num_mdef,
    :calc_flags => [:mdef],
    :fail => [:mdefset]
  },
  %{
    :status => :darkcrow,
    :icon => :efst_darkcrow,
    :duration_lookup => :gc_darkcrow,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :full_throttle,
    :icon => :efst_full_throttle,
    :duration_lookup => :all_full_throttle,
    :calc_flags => [
      :speed,
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :rebound,
    :icon => :efst_rebound,
    :calc_flags => [
      :speed,
      :regen
    ],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :unlimit,
    :icon => :efst_unlimit,
    :duration_lookup => :ra_unlimit,
    :flags => [
      :displaypc,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :kings_grace,
    :icon => :efst_kings_grace,
    :duration_lookup => :lg_kings_grace,
    :states => [
      :nocast,
      :noattack,
      :nomove,
      :noconsumeitem
    ],
    :flags => [
      :stopattacking,
      :stopwalking,
      :stopcasting
    ],
    :fail => [
      :devotion,
      :whiteimprison
    ],
    :end_on_start => [
      :poison,
      :blind,
      :freeze,
      :stone,
      :stun,
      :sleep,
      :bleeding,
      :curse,
      :confusion,
      :hallucination,
      :silence,
      :burning,
      :crystalize,
      :freezing,
      :deepsleep,
      :fear,
      :mandragora
    ]
  },
  %{
    :status => :telekinesis_intense,
    :icon => :efst_telekinesis_intense,
    :duration_lookup => :wl_telekinesis_intense,
    :calc_flags => [:matk],
    :flags => [
      :displaypc,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :offertorium,
    :icon => :efst_offertorium,
    :duration_lookup => :ab_offertorium,
    :flags => [:displaypc],
    :fail => [:magnificat],
    :end_on_start => [
      :magnificat,
      :blind,
      :curse,
      :poison,
      :hallucination,
      :confusion,
      :bleeding,
      :burning,
      :freezing,
      :mandragora,
      :paralyse,
      :pyrexia,
      :deathhurt,
      :leechesend,
      :venombleed,
      :toxin,
      :magicmushroom
    ]
  },
  %{
    :status => :frigg_song,
    :icon => :efst_frigg_song,
    :duration_lookup => :wm_frigg_song,
    :calc_flags => [:maxhp]
  },
  %{
    :status => :monster_transform,
    :icon => :efst_monster_transform,
    :flags => [
      :displaypc,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :angel_protect,
    :icon => :efst_angel_protect,
    :flags => [
      :noclearance,
      :nobanishingbuster,
      :nodispell
    ]
  },
  %{
    :status => :illusiondoping,
    :icon => :efst_illusiondoping,
    :duration_lookup => :gn_illusiondoping,
    :calc_flags => [:hit],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :flashcombo,
    :icon => :efst_flashcombo,
    :duration_lookup => :sr_flashcombo,
    :calc_flags => [:watk]
  },
  %{
    :status => :moonstar,
    :icon => :efst_moonstar,
    :flags => [
      :nosave,
      :bleffect,
      :displaypc,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :super_star,
    :icon => :efst_super_star,
    :flags => [
      :nosave,
      :bleffect,
      :displaypc,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :heat_barrel,
    :icon => :efst_heat_barrel,
    :duration_lookup => :rl_heat_barrel,
    :calc_flags => [
      :hit,
      :aspd
    ],
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :removeonunequip
    ],
    :fail => [
      :p_alter,
      :madnesscancel
    ]
  },
  %{
    :status => :magicalbullet,
    :icon => :efst_gs_magical_bullet,
    :duration_lookup => :gs_magicalbullet
  },
  %{
    :status => :p_alter,
    :icon => :efst_p_alter,
    :duration_lookup => :rl_p_alter,
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [
      :heat_barrel,
      :madnesscancel
    ]
  },
  %{
    :status => :e_chain,
    :icon => :efst_e_chain,
    :duration_lookup => :rl_e_chain,
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :c_marker,
    :icon => :efst_c_marker,
    :duration_lookup => :rl_c_marker,
    :calc_flags => [:flee],
    :flags => [
      :bleffect,
      :displaypc,
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :anti_m_blast,
    :icon => :efst_anti_m_blast,
    :duration_lookup => :rl_am_blast,
    :flags => [
      :bleffect,
      :displaypc,
      :debuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :b_trap,
    :icon => :efst_b_trap,
    :duration_lookup => :rl_b_trap,
    :calc_flags => [:speed],
    :flags => [
      :debuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :h_mine,
    :icon => :efst_h_mine,
    :duration_lookup => :rl_h_mine,
    :flags => [
      :debuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :qd_shot_ready,
    :icon => :efst_e_qd_shot_ready,
    :flags => [:nosave]
  },
  %{
    :status => :mtf_aspd,
    :icon => :efst_mtf_aspd,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bAspd, getstatus(SC_MTF_ASPD, 1);
bonus bHit, getstatus(SC_MTF_ASPD, 2);
"
  },
  %{
    :status => :mtf_rangeatk,
    :icon => :efst_mtf_rangeatk,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bLongAtkRate, getstatus(SC_MTF_RANGEATK, 1);
"
  },
  %{
    :status => :mtf_matk,
    :icon => :efst_mtf_matk,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bMatk, getstatus(SC_MTF_MATK, 1);
"
  },
  %{
    :status => :mtf_mleatked,
    :icon => :efst_mtf_mleatked,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => ".@val1 = getstatus(SC_MTF_MLEATKED, 1);
.@val2 = getstatus(SC_MTF_MLEATKED, 2);
.@val3 = getstatus(SC_MTF_MLEATKED, 3);
bonus4 bAutoSpellWhenHit,"SM_ENDURE",.@val1,.@val2,0;
bonus2 bSubEle,Ele_Neutral, .@val3;
"
  },
  %{
    :status => :mtf_cridamage,
    :icon => :efst_mtf_cridamage,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bCritAtkRate, getstatus(SC_MTF_CRIDAMAGE, 1);
"
  },
  %{
    :status => :oktoberfest,
    :states => [:noattack],
    :options => [:oktoberfest],
    :flags => [
      :sendlook,
      :stopattacking,
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :strangelights,
    :icon => :efst_strangelights,
    :flags => [
      :nosave,
      :displaypc,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :bleffect
    ]
  },
  %{
    :status => :decoration_of_music,
    :icon => :efst_decoration_of_music,
    :flags => [
      :nosave,
      :displaypc,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :bleffect
    ]
  },
  %{
    :status => :quest_buff1,
    :icon => :efst_quest_buff1,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_QUEST_BUFF1, 1);
bonus bMatk, .@val1;
bonus bBaseAtk, .@val1;
"
  },
  %{
    :status => :quest_buff2,
    :icon => :efst_quest_buff2,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_QUEST_BUFF2, 1);
bonus bMatk, .@val1;
bonus bBaseAtk, .@val1;
"
  },
  %{
    :status => :quest_buff3,
    :icon => :efst_quest_buff3,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_QUEST_BUFF3, 1);
bonus bMatk, .@val1;
bonus bBaseAtk, .@val1;
"
  },
  %{
    :status => :all_riding,
    :icon => :efst_all_riding,
    :states => [:noattack],
    :calc_flags => [:speed],
    :flags => [
      :bleffect,
      :displaypc,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :end_return => [:all_riding]
  },
  %{
    :status => :teargas_sob,
    :flags => [:bossresist]
  },
  %{
    :status => :_feintbomb,
    :duration_lookup => :sc_feintbomb,
    :states => [:nopickitem],
    :options => [:invisible],
    :flags => [
      :unitmove,
      :ontouch,
      :stopattacking
    ]
  },
  %{
    :status => :_chaos,
    :flags => [:stopwalking],
    :fail => [:_chaos]
  },
  %{
    :status => :chasewalk2,
    :icon => :efst_chasewalk2,
    :calc_flags => [:str],
    :flags => [
      :nosave,
      :noclearance,
      :removeonchangemap,
      :nobanishingbuster,
      :nodispell,
      :removeonhermode
    ]
  },
  %{
    :status => :mtf_aspd2,
    :icon => :efst_mtf_aspd2,
    :calc_flags => [
      :aspd,
      :hit
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bAspd, getstatus(SC_MTF_ASPD2, 1);
bonus bHit, getstatus(SC_MTF_ASPD2, 2);
"
  },
  %{
    :status => :mtf_rangeatk2,
    :icon => :efst_mtf_rangeatk2,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bLongAtkRate, getstatus(SC_MTF_RANGEATK2, 1);
"
  },
  %{
    :status => :mtf_matk2,
    :icon => :efst_mtf_matk2,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bMatk, getstatus(SC_MTF_MATK2, 1);
"
  },
  %{
    :status => :"2011rwc_scroll",
    :icon => :efst_2011rwc_scroll,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@level = max(3, getskilllv("AC_CONCENTRATION"));
bonus bBaseAtk,30;
bonus bMatk,30;
bonus bAspdRate,5;
bonus bVariableCastrate,-5;
bonus bMaxHPrate,-10;
bonus bMaxSPrate,-10;
bonus3 bAutoSpell,"AC_CONCENTRATION",.@level,10;   /* TODO: unknown rate */
"
  },
  %{
    :status => :jp_event04,
    :icon => :efst_jp_event04,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ],
    :script => "bonus2 bExpAddRace,RC_Fish, getstatus(SC_JP_EVENT04, 1);
"
  },
  %{
    :status => :mtf_mhp,
    :icon => :efst_mtf_mhp,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bMaxHPrate, getstatus(SC_MTF_MHP, 1);
"
  },
  %{
    :status => :mtf_msp,
    :icon => :efst_mtf_msp,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus bMaxSPrate, getstatus(SC_MTF_MSP, 1);
"
  },
  %{
    :status => :mtf_pumpkin,
    :icon => :efst_mtf_pumpkin,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => "bonus2 bAddItemHealRate,535,2000;
bonus2 bAddItemHealRate,11605, getstatus(SC_MTF_PUMPKIN, 1);
"
  },
  %{
    :status => :mtf_hitflee,
    :icon => :efst_mtf_hitflee,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :script => ".@val1 = getstatus(SC_MTF_HITFLEE, 1);
.@val2 = getstatus(SC_MTF_HITFLEE, 2);
bonus bHit, .@val1;
bonus bCritical, .@val1;
bonus bFlee, .@val2;
"
  },
  %{
    :status => :vacuum_extreme_postdelay,
    :duration_lookup => :so_vacuum_extreme,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :crifood,
    :icon => :efst_food_criticalsuccessvalue,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bCritical, getstatus(SC_CRIFOOD, 1);
"
  },
  %{
    :status => :atthaste_cash,
    :icon => :efst_atthaste_cash,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :overlapignorelevel,
      :noforcedend
    ],
    :script => "bonus bAspdRate, getstatus(SC_ATTHASTE_CASH, 1);
"
  },
  %{
    :status => :reuse_limit_a,
    :icon => :efst_reuse_limit_a,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_a]
  },
  %{
    :status => :reuse_limit_b,
    :icon => :efst_reuse_limit_b,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_b]
  },
  %{
    :status => :reuse_limit_c,
    :icon => :efst_reuse_limit_c,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_c]
  },
  %{
    :status => :reuse_limit_d,
    :icon => :efst_reuse_limit_d,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_d]
  },
  %{
    :status => :reuse_limit_e,
    :icon => :efst_reuse_limit_e,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_e]
  },
  %{
    :status => :reuse_limit_f,
    :icon => :efst_reuse_limit_f,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_f]
  },
  %{
    :status => :reuse_limit_g,
    :icon => :efst_reuse_limit_g,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_g]
  },
  %{
    :status => :reuse_limit_h,
    :icon => :efst_reuse_limit_h,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_h]
  },
  %{
    :status => :reuse_limit_mtf,
    :icon => :efst_reuse_limit_mtf,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_mtf]
  },
  %{
    :status => :reuse_limit_aspd_potion,
    :icon => :efst_reuse_limit_aspd_potion,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_aspd_potion]
  },
  %{
    :status => :reuse_millenniumshield,
    :icon => :efst_reuse_millenniumshield,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_millenniumshield]
  },
  %{
    :status => :reuse_crushstrike,
    :icon => :efst_reuse_crushstrike,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_crushstrike]
  },
  %{
    :status => :reuse_stormblast,
    :icon => :efst_reuse_stormblast,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_stormblast]
  },
  %{
    :status => :all_riding_reuse_limit,
    :icon => :efst_all_riding_reuse_limit,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:all_riding_reuse_limit]
  },
  %{
    :status => :reuse_limit_ecl,
    :icon => :efst_reuse_limit_ecl,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_ecl]
  },
  %{
    :status => :reuse_limit_recall,
    :icon => :efst_reuse_limit_recall,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noforcedend
    ],
    :fail => [:reuse_limit_recall]
  },
  %{
    :status => :promote_health_reserch,
    :icon => :efst_promote_health_reserch,
    :calc_flags => [:maxhp]
  },
  %{
    :status => :energy_drink_reserch,
    :icon => :efst_energy_drink_reserch,
    :calc_flags => [:maxsp]
  },
  %{
    :status => :norecover_state,
    :icon => :efst_handicapstate_norecover,
    :calc_flags => [:regen]
  },
  %{
    :status => :suhide,
    :icon => :efst_suhide,
    :duration_lookup => :su_hide,
    :states => [
      :nomove,
      :nopickitem,
      :noconsumeitem,
      :noattack,
      :nointeract
    ],
    :flags => [
      :stopattacking,
      :removeondamaged,
      :removeonchangemap,
      :removeonmapwarp
    ]
  },
  %{
    :status => :su_stoop,
    :icon => :efst_su_stoop,
    :duration_lookup => :su_stoop
  },
  %{
    :status => :spritemable,
    :icon => :efst_spritemable,
    :flags => [
      :displaypc,
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :noclearbuff
    ]
  },
  %{
    :status => :catnippowder,
    :icon => :efst_catnippowder,
    :duration_lookup => :su_cn_powdering,
    :calc_flags => [:all],
    :flags => [:bossresist]
  },
  %{
    :status => :sv_roottwist,
    :icon => :efst_sv_roottwist,
    :duration_lookup => :su_sv_roottwist,
    :states => [:nomove],
    :flags => [
      :bleffect,
      :displaypc,
      :bossresist,
      :stopwalking,
      :nosave
    ]
  },
  %{
    :status => :bitescar,
    :icon => :efst_bitescar,
    :duration_lookup => :su_scaroftarou,
    :flags => [
      :bossresist,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster
    ]
  },
  %{
    :status => :arclousedash,
    :icon => :efst_arclousedash,
    :duration_lookup => :su_arclousedash,
    :calc_flags => [
      :agi,
      :speed
    ]
  },
  %{
    :status => :tunaparty,
    :icon => :efst_tunaparty,
    :duration_lookup => :su_tunaparty,
    :flags => [:nodispell]
  },
  %{
    :status => :shrimp,
    :icon => :efst_shrimp,
    :duration_lookup => :su_bunchofshrimp,
    :calc_flags => [:all]
  },
  %{
    :status => :freshshrimp,
    :icon => :efst_freshshrimp,
    :duration_lookup => :su_freshshrimp,
    :flags => [:bossresist]
  },
  %{
    :status => :active_monster_transform,
    :icon => :efst_active_monster_transform,
    :flags => [
      :displaypc,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1,
      :noforcedend
    ]
  },
  %{
    :status => :ljosalfar,
    :icon => :efst_ljosalfar,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :mermaid_longing,
    :icon => :efst_mermaid_longing,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :hat_effect,
    :icon => :efst_hat_effect,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :flowersmoke,
    :icon => :efst_flowersmoke,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :fstone,
    :icon => :efst_fstone,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :happiness_star,
    :icon => :efst_happiness_star,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :maple_falls,
    :icon => :efst_maple_falls,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :time_accessory,
    :icon => :efst_time_accessory,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :magical_feather,
    :icon => :efst_magical_feather,
    :flags => [
      :bleffect,
      :displaypc,
      :noremoveondead,
      :nosave,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :gvg_giant,
    :icon => :efst_gvg_giant
  },
  %{
    :status => :gvg_golem,
    :icon => :efst_gvg_golem
  },
  %{
    :status => :gvg_stun,
    :icon => :efst_gvg_stun,
    :end_on_start => [:gvg_stun]
  },
  %{
    :status => :gvg_stone,
    :icon => :efst_gvg_stone,
    :end_on_start => [:stone]
  },
  %{
    :status => :gvg_freez,
    :icon => :efst_gvg_freez,
    :end_on_start => [:freeze]
  },
  %{
    :status => :gvg_sleep,
    :icon => :efst_gvg_sleep,
    :end_on_start => [:sleep]
  },
  %{
    :status => :gvg_curse,
    :icon => :efst_gvg_curse,
    :end_on_start => [:curse]
  },
  %{
    :status => :gvg_silence,
    :icon => :efst_gvg_silence,
    :end_on_start => [:silence]
  },
  %{
    :status => :gvg_blind,
    :icon => :efst_gvg_blind,
    :end_on_start => [:blind]
  },
  %{
    :status => :clan_info,
    :icon => :efst_clan_info,
    :flags => [
      :displaypc,
      :displaynpc,
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval2
    ]
  },
  %{
    :status => :swordclan,
    :icon => :efst_swordclan,
    :calc_flags => [
      :str,
      :vit,
      :maxhp,
      :maxsp
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ],
    :end_on_end => [:clan_info]
  },
  %{
    :status => :arcwandclan,
    :icon => :efst_arcwandclan,
    :calc_flags => [
      :int,
      :dex,
      :maxhp,
      :maxsp
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ],
    :end_on_end => [:clan_info]
  },
  %{
    :status => :goldenmaceclan,
    :icon => :efst_goldenmaceclan,
    :calc_flags => [
      :luk,
      :int,
      :maxhp,
      :maxsp
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ],
    :end_on_end => [:clan_info]
  },
  %{
    :status => :crossbowclan,
    :icon => :efst_crossbowclan,
    :calc_flags => [
      :agi,
      :vit,
      :maxhp,
      :maxsp
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ],
    :end_on_end => [:clan_info]
  },
  %{
    :status => :jumpingclan,
    :icon => :efst_jumpingclan,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ],
    :end_on_end => [:clan_info]
  },
  %{
    :status => :tarotcard,
    :icon => :efst_tarotcard,
    :duration_lookup => :cg_tarotcard
  },
  %{
    :status => :geffen_magic1,
    :icon => :efst_geffen_magic1,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :removeonhermode
    ],
    :script => ".@val1 = getstatus(SC_GEFFEN_MAGIC1, 1);
bonus2 bAddRace,RC_Player_Human, .@val1;
bonus2 bAddRace,RC_DemiHuman, .@val1;
"
  },
  %{
    :status => :geffen_magic2,
    :icon => :efst_geffen_magic2,
    :flags => [
      :noremoveondead,
      :noclearbuff
    ],
    :script => ".@val1 = getstatus(SC_GEFFEN_MAGIC2, 1);
bonus2 bMagicAddRace,RC_Player_Human, .@val1;
bonus2 bMagicAddRace,RC_DemiHuman, .@val1;
"
  },
  %{
    :status => :geffen_magic3,
    :icon => :efst_geffen_magic3,
    :flags => [
      :noremoveondead,
      :noclearbuff
    ],
    :script => ".@val1 = getstatus(SC_GEFFEN_MAGIC3, 1);
bonus2 bSubRace,RC_Player_Human, .@val1;
bonus2 bSubRace,RC_DemiHuman, .@val1;
"
  },
  %{
    :status => :maxpain,
    :icon => :efst_maxpain,
    :duration_lookup => :npc_maxpain,
    :flags => [:bleffect]
  },
  %{
    :status => :armor_element_earth,
    :icon => :efst_resist_property_ground,
    :flags => [
      :nodispell,
      :overlapignorelevel
    ],
    :script => "bonus2 bSubEle,Ele_Water, getstatus(SC_ARMOR_ELEMENT_EARTH, 1);
bonus2 bSubEle,Ele_Earth, getstatus(SC_ARMOR_ELEMENT_EARTH, 2);
bonus2 bSubEle,Ele_Fire, getstatus(SC_ARMOR_ELEMENT_EARTH, 3);
bonus2 bSubEle,Ele_Wind, getstatus(SC_ARMOR_ELEMENT_EARTH, 4);
"
  },
  %{
    :status => :armor_element_fire,
    :icon => :efst_resist_property_fire,
    :flags => [
      :nodispell,
      :overlapignorelevel
    ],
    :script => "bonus2 bSubEle,Ele_Water, getstatus(SC_ARMOR_ELEMENT_FIRE, 1);
bonus2 bSubEle,Ele_Earth, getstatus(SC_ARMOR_ELEMENT_FIRE, 2);
bonus2 bSubEle,Ele_Fire, getstatus(SC_ARMOR_ELEMENT_FIRE, 3);
bonus2 bSubEle,Ele_Wind, getstatus(SC_ARMOR_ELEMENT_FIRE, 4);
"
  },
  %{
    :status => :armor_element_wind,
    :icon => :efst_resist_property_wind,
    :flags => [
      :nodispell,
      :overlapignorelevel
    ],
    :script => "bonus2 bSubEle,Ele_Water, getstatus(SC_ARMOR_ELEMENT_WIND, 1);
bonus2 bSubEle,Ele_Earth, getstatus(SC_ARMOR_ELEMENT_WIND, 2);
bonus2 bSubEle,Ele_Fire, getstatus(SC_ARMOR_ELEMENT_WIND, 3);
bonus2 bSubEle,Ele_Wind, getstatus(SC_ARMOR_ELEMENT_WIND, 4);
"
  },
  %{
    :status => :dailysendmailcnt,
    :icon => :efst_dailysendmailcnt,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :noclearance,
      :nobanishingbuster,
      :sendval2
    ]
  },
  %{
    :status => :doram_buf_01,
    :icon => :efst_doram_buf_01,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :fail => [:doram_buf_01],
    :script => "bonus2 bHPRegenRate,10,10000;
"
  },
  %{
    :status => :doram_buf_02,
    :icon => :efst_doram_buf_02,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :fail => [:doram_buf_02],
    :script => "bonus2 bSPRegenRate,5,10000;
"
  },
  %{
    :status => :hiss,
    :icon => :efst_hiss,
    :duration_lookup => :su_hiss,
    :calc_flags => [:flee2],
    :flags => [:noremoveondead]
  },
  %{
    :status => :nyanggrass,
    :icon => :efst_nyanggrass,
    :duration_lookup => :su_nyanggrass,
    :calc_flags => [
      :def,
      :mdef
    ],
    :flags => [:noremoveondead]
  },
  %{
    :status => :grooming,
    :icon => :efst_grooming,
    :duration_lookup => :su_grooming,
    :calc_flags => [:flee],
    :flags => [:noremoveondead],
    :fail => [:grooming],
    :end_on_start => [
      :stun,
      :freeze,
      :stone,
      :sleep,
      :silence,
      :bleeding,
      :poison,
      :fear,
      :mandragora,
      :crystalize,
      :freezing
    ]
  },
  %{
    :status => :shrimpblessing,
    :icon => :efst_protectionofshrimp,
    :duration_lookup => :su_shrimparty,
    :calc_flags => [:regen],
    :flags => [:noremoveondead]
  },
  %{
    :status => :chattering,
    :icon => :efst_chattering,
    :duration_lookup => :su_chattering,
    :calc_flags => [
      :watk,
      :matk
    ],
    :flags => [:noremoveondead],
    :fail => [:chattering]
  },
  %{
    :status => :doram_walkspeed,
    :calc_flags => [:speed]
  },
  %{
    :status => :doram_matk,
    :calc_flags => [:matk]
  },
  %{
    :status => :doram_flee2,
    :calc_flags => [:flee2]
  },
  %{
    :status => :doram_svsp,
    :flags => [:nowarning]
  },
  %{
    :status => :fallen_angel,
    :duration_lookup => :rl_fallen_angel
  },
  %{
    :status => :cheerup,
    :icon => :efst_cheerup,
    :duration_lookup => :we_cheerup,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :flags => [:noremoveondead]
  },
  %{
    :status => :dressup,
    :icon => :efst_dress_up,
    :states => [:noattack],
    :options => [:summer2],
    :flags => [
      :displaypc,
      :sendlook,
      :stopattacking,
      :noremoveondead,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :glastheim_atk,
    :icon => :efst_glastheim_atk,
    :flags => [:nosave],
    :script => ".@val1 = getstatus(SC_GLASTHEIM_ATK, 1);
bonus2 bAddRace2,RC2_OGH_ATK_DEF, .@val1;
bonus2 bMagicAddRace2,RC2_OGH_ATK_DEF, .@val1;
bonus2 bIgnoreDefRaceRate,RC_Undead, .@val1;
bonus2 bIgnoreDefRaceRate,RC_Demon, .@val1;
"
  },
  %{
    :status => :glastheim_def,
    :icon => :efst_glastheim_def,
    :flags => [:nosave],
    :script => "bonus2 bSubRace2,RC2_OGH_ATK_DEF, getstatus(SC_GLASTHEIM_DEF, 1);
"
  },
  %{
    :status => :glastheim_heal,
    :icon => :efst_glastheim_heal,
    :flags => [:nosave],
    :script => "bonus bHealPower, getstatus(SC_GLASTHEIM_HEAL, 1);
bonus bHealPower2, getstatus(SC_GLASTHEIM_HEAL, 2);
"
  },
  %{
    :status => :glastheim_hidden,
    :icon => :efst_glastheim_hidden,
    :flags => [:nosave],
    :script => "bonus2 bSubRace2,RC2_OGH_HIDDEN, getstatus(SC_GLASTHEIM_HIDDEN, 1);
"
  },
  %{
    :status => :glastheim_state,
    :icon => :efst_glastheim_state,
    :flags => [:nosave],
    :script => "bonus bAllStats, getstatus(SC_GLASTHEIM_STATE, 1);
"
  },
  %{
    :status => :glastheim_itemdef,
    :icon => :efst_glastheim_itemdef,
    :flags => [:nosave],
    :script => "bonus bDef, getstatus(SC_GLASTHEIM_ITEMDEF, 1);
bonus bMdef, getstatus(SC_GLASTHEIM_ITEMDEF, 2);
"
  },
  %{
    :status => :glastheim_hpsp,
    :icon => :efst_glastheim_hpsp,
    :flags => [:nosave],
    :script => "bonus bMaxHP, getstatus(SC_GLASTHEIM_HPSP, 1);
bonus bMaxSP, getstatus(SC_GLASTHEIM_HPSP, 2);
"
  },
  %{
    :status => :lhz_dun_n1,
    :icon => :efst_lhz_dun_n1,
    :flags => [
      :noclearbuff,
      :noclearance,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :overlapignorelevel
    ],
    :script => ".@val1 = getstatus(SC_LHZ_DUN_N1, 1);
.@val2 = getstatus(SC_LHZ_DUN_N1, 2);
bonus2 bAddRace2,RC2_BIO5_SWORDMAN_THIEF, .@val1;
bonus2 bMagicAddRace2,RC2_BIO5_SWORDMAN_THIEF, .@val1;
bonus2 bSubRace2,RC2_BIO5_ACOLYTE_MERCHANT, .@val2;
"
  },
  %{
    :status => :lhz_dun_n2,
    :icon => :efst_lhz_dun_n2,
    :flags => [
      :noclearbuff,
      :noclearance,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :overlapignorelevel
    ],
    :script => ".@val1 = getstatus(SC_LHZ_DUN_N2, 1);
.@val2 = getstatus(SC_LHZ_DUN_N2, 2);
bonus2 bAddRace2,RC2_BIO5_ACOLYTE_MERCHANT, .@val1;
bonus2 bMagicAddRace2,RC2_BIO5_ACOLYTE_MERCHANT, .@val1;
bonus2 bSubRace2,RC2_BIO5_MAGE_ARCHER, .@val2;
"
  },
  %{
    :status => :lhz_dun_n3,
    :icon => :efst_lhz_dun_n3,
    :flags => [
      :noclearbuff,
      :noclearance,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :overlapignorelevel
    ],
    :script => ".@val1 = getstatus(SC_LHZ_DUN_N3, 1);
.@val2 = getstatus(SC_LHZ_DUN_N3, 2);
bonus2 bAddRace2,RC2_BIO5_MAGE_ARCHER, .@val1;
bonus2 bMagicAddRace2,RC2_BIO5_MAGE_ARCHER, .@val1;
bonus2 bSubRace2,RC2_BIO5_SWORDMAN_THIEF, .@val2;
"
  },
  %{
    :status => :lhz_dun_n4,
    :icon => :efst_lhz_dun_n4,
    :flags => [
      :noclearbuff,
      :noclearance,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :overlapignorelevel
    ],
    :script => ".@val1 = getstatus(SC_LHZ_DUN_N4, 1);
.@val2 = getstatus(SC_LHZ_DUN_N4, 2);
bonus2 bAddRace2,RC2_BIO5_MVP, .@val1;
bonus2 bMagicAddRace2,RC2_BIO5_MVP, .@val1;
bonus2 bSubRace2,RC2_BIO5_MVP, .@val2;
"
  },
  %{
    :status => :ancilla,
    :icon => :efst_ancilla,
    :calc_flags => [:regen],
    :flags => [:noremoveondead]
  },
  %{
    :status => :earthshaker,
    :icon => :efst_earthshaker,
    :flags => [
      :bleffect,
      :nowarning
    ]
  },
  %{
    :status => :weaponblock_on,
    :icon => :efst_weaponblock_on,
    :duration_lookup => :shc_impact_crater,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :noclearbuff
    ]
  },
  %{
    :status => :spore_explosion,
    :icon => :efst_spore_explosion_debuff,
    :duration_lookup => :gn_spore_explosion,
    :flags => [
      :bleffect,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :adaptation,
    :icon => :efst_adaptation,
    :duration_lookup => :bd_adaptation
  },
  %{
    :status => :entry_queue_apply_delay,
    :icon => :efst_entry_queue_apply_delay,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :noclearbuff
    ]
  },
  %{
    :status => :entry_queue_notify_admission_time_out,
    :icon => :efst_entry_queue_notify_admission_time_out,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :noremoveondead,
      :noclearbuff
    ]
  },
  %{
    :status => :lightofmoon,
    :icon => :efst_lightofmoon,
    :duration_lookup => :sj_lightofmoon,
    :end_on_start => [
      :lunarstance,
      :universestance
    ]
  },
  %{
    :status => :lightofsun,
    :icon => :efst_lightofsun,
    :duration_lookup => :sj_lightofsun,
    :end_on_start => [
      :lightofsun,
      :universestance
    ]
  },
  %{
    :status => :lightofstar,
    :icon => :efst_lightofstar,
    :duration_lookup => :sj_lightofstar,
    :end_on_start => [
      :starstance,
      :universestance
    ]
  },
  %{
    :status => :lunarstance,
    :icon => :efst_lunarstance,
    :duration_lookup => :sj_lunarstance,
    :calc_flags => [:maxhp],
    :end_on_start => [
      :sunstance,
      :starstance,
      :universestance
    ],
    :end_on_end => [
      :newmoon,
      :lightofmoon
    ]
  },
  %{
    :status => :universestance,
    :icon => :efst_universestance,
    :duration_lookup => :sj_universestance,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :end_on_start => [
      :sunstance,
      :lunarstance,
      :starstance
    ],
    :end_on_end => [
      :lightofsun,
      :newmoon,
      :lightofmoon,
      :fallingstar,
      :lightofstar,
      :dimension
    ]
  },
  %{
    :status => :sunstance,
    :icon => :efst_sunstance,
    :duration_lookup => :sj_sunstance,
    :calc_flags => [
      :batk,
      :watk
    ],
    :end_on_start => [
      :lunarstance,
      :starstance,
      :universestance
    ],
    :end_on_end => [:lightofsun]
  },
  %{
    :status => :flashkick,
    :icon => :efst_flashkick,
    :duration_lookup => :sj_flashkick,
    :flags => [
      :removeonchangemap,
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :overlapignorelevel
    ]
  },
  %{
    :status => :newmoon,
    :icon => :efst_newmoon,
    :duration_lookup => :sj_newmoonkick,
    :states => [:nopickitem],
    :options => [:cloak],
    :flags => [
      :ontouch,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :stopattacking,
      :removeondamaged,
      :removeonchangemap
    ],
    :fail => [:bite]
  },
  %{
    :status => :starstance,
    :icon => :efst_starstance,
    :duration_lookup => :sj_starstance,
    :calc_flags => [:aspd],
    :end_on_start => [
      :sunstance,
      :lunarstance,
      :universestance
    ],
    :end_on_end => [
      :fallingstar,
      :lightofstar
    ]
  },
  %{
    :status => :dimension,
    :icon => :efst_dimension,
    :duration_lookup => :sj_bookofdimension,
    :flags => [:noclearance]
  },
  %{
    :status => :dimension1,
    :flags => [:nowarning]
  },
  %{
    :status => :dimension2,
    :flags => [:nowarning]
  },
  %{
    :status => :creatingstar,
    :icon => :efst_creatingstar,
    :duration_lookup => :sj_bookofcreatingstar,
    :calc_flags => [:speed],
    :flags => [:debuff],
    :fail => [:speedup1]
  },
  %{
    :status => :fallingstar,
    :icon => :efst_fallingstar,
    :duration_lookup => :sj_fallingstar
  },
  %{
    :status => :novaexplosing,
    :icon => :efst_novaexplosing,
    :duration_lookup => :sj_novaexplosing,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :gravitycontrol,
    :icon => :efst_gravitycontrol,
    :duration_lookup => :sj_gravitycontrol,
    :states => [
      :nomove,
      :nocast,
      :noattack,
      :nointeract
    ],
    :flags => [
      :stopcasting,
      :stopattacking,
      :stopwalking
    ]
  },
  %{
    :status => :soulcollect,
    :icon => :efst_soulcollect,
    :duration_lookup => :sp_soulcollect,
    :min_duration => 1000
  },
  %{
    :status => :soulreaper,
    :icon => :efst_soulreaper,
    :duration_lookup => :sp_soulreaper
  },
  %{
    :status => :soulunity,
    :icon => :efst_soulunity,
    :duration_lookup => :sp_soulunity,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :overlapignorelevel
    ]
  },
  %{
    :status => :soulshadow,
    :icon => :efst_soulshadow,
    :duration_lookup => :sp_soulshadow,
    :calc_flags => [
      :aspd,
      :cri
    ],
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [
      :spirit,
      :soulgolem,
      :soulfalcon,
      :soulfairy
    ]
  },
  %{
    :status => :soulfairy,
    :icon => :efst_soulfairy,
    :duration_lookup => :sp_soulfairy,
    :calc_flags => [:matk],
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [
      :spirit,
      :soulgolem,
      :soulshadow,
      :soulfalcon
    ]
  },
  %{
    :status => :soulfalcon,
    :icon => :efst_soulfalcon,
    :duration_lookup => :sp_soulfalcon,
    :calc_flags => [
      :watk,
      :hit
    ],
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [
      :spirit,
      :soulgolem,
      :soulshadow,
      :soulfairy
    ]
  },
  %{
    :status => :soulgolem,
    :icon => :efst_soulgolem,
    :duration_lookup => :sp_soulgolem,
    :calc_flags => [
      :def,
      :mdef
    ],
    :flags => [
      :nosave,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :fail => [
      :spirit,
      :soulshadow,
      :soulfalcon,
      :soulfairy
    ]
  },
  %{
    :status => :souldivision,
    :icon => :efst_souldivision,
    :duration_lookup => :sp_souldivision
  },
  %{
    :status => :soulenergy,
    :icon => :efst_soulenergy,
    :calc_flags => [:matk],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :use_skill_sp_spa,
    :icon => :efst_use_skill_sp_spa,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :use_skill_sp_sha,
    :icon => :efst_use_skill_sp_sha,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :sp_sha,
    :icon => :efst_sp_sha,
    :duration_lookup => :sp_sha,
    :calc_flags => [:speed],
    :flags => [
      :bossresist,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :soulcurse,
    :icon => :efst_soulcurse,
    :duration_lookup => :sp_soulcurse,
    :flags => [:bleffect]
  },
  %{
    :status => :hells_plant,
    :icon => :efst_hells_plant_armor,
    :duration_lookup => :gn_hells_plant,
    :flags => [
      :nosave,
      :displaypc,
      :bleffect
    ]
  },
  %{
    :status => :increase_maxhp,
    :icon => :efst_atker_aspd,
    :script => "bonus bMaxHPrate, getstatus(SC_INCREASE_MAXHP, 1);
bonus bHPrecovRate, getstatus(SC_INCREASE_MAXHP, 2);
"
  },
  %{
    :status => :increase_maxsp,
    :icon => :efst_atker_movespeed,
    :script => "bonus bMaxSPrate, getstatus(SC_INCREASE_MAXSP, 1);
bonus bSPrecovRate, getstatus(SC_INCREASE_MAXSP, 2);
"
  },
  %{
    :status => :ref_t_potion,
    :icon => :efst_ref_t_potion
  },
  %{
    :status => :add_atk_damage,
    :icon => :efst_add_atk_damage
  },
  %{
    :status => :add_matk_damage,
    :icon => :efst_add_matk_damage
  },
  %{
    :status => :helpangel,
    :icon => :efst_helpangel,
    :duration_lookup => :nv_helpangel
  },
  %{
    :status => :soundofdestruction,
    :icon => :efst_sound_of_destruction,
    :duration_lookup => :wm_sound_of_destruction
  },
  %{
    :status => :luxanima,
    :icon => :efst_luxanima,
    :duration_lookup => :rk_luxanima,
    :calc_flags => [:all],
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noclearbuff
    ]
  },
  %{
    :status => :reuse_limit_luxanima,
    :icon => :efst_reuse_limit_luxanima,
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noremoveondead,
      :noclearbuff
    ],
    :fail => [:reuse_limit_luxanima]
  },
  %{
    :status => :ensemblefatigue,
    :icon => :efst_ensemblefatigue,
    :states => [:nocast],
    :calc_flags => [
      :speed,
      :aspd
    ]
  },
  %{
    :status => :misty_frost,
    :icon => :efst_misty_frost,
    :flags => [
      :displaypc,
      :sendval1
    ]
  },
  %{
    :status => :magic_poison,
    :icon => :efst_magic_poison,
    :duration_lookup => :wl_comet,
    :flags => [
      :displaypc,
      :bleffect
    ]
  },
  %{
    :status => :ep16_2_buff_ss,
    :icon => :efst_ep16_2_buff_ss,
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noclearbuff
    ],
    :script => "bonus bAspd,10;
"
  },
  %{
    :status => :ep16_2_buff_sc,
    :icon => :efst_ep16_2_buff_sc,
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noclearbuff
    ],
    :script => "bonus bCritical,30;
"
  },
  %{
    :status => :ep16_2_buff_ac,
    :icon => :efst_ep16_2_buff_ac,
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noclearbuff
    ],
    :script => "bonus bVariableCastrate,-80;
"
  },
  %{
    :status => :overbrandready,
    :icon => :efst_overbrandready
  },
  %{
    :status => :poison_mist,
    :icon => :efst_poison_mist,
    :duration_lookup => :mh_poison_mist,
    :calc_flags => [:flee]
  },
  %{
    :status => :stone_wall,
    :icon => :efst_stone_wall,
    :duration_lookup => :mh_steinwand,
    :calc_flags => [
      :def,
      :mdef
    ]
  },
  %{
    :status => :cloud_poison,
    :icon => :efst_cloud_poison,
    :duration_lookup => :so_cloud_kill,
    :flags => [:bleffect],
    :fail => [:cloud_poison]
  },
  %{
    :status => :homun_time,
    :icon => :efst_homun_time,
    :flags => [
      :displaypc,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noclearbuff
    ]
  },
  %{
    :status => :emergency_move,
    :icon => :efst_inc_agi,
    :duration_lookup => :gd_emergency_move,
    :calc_flags => [:speed],
    :flags => [
      :nosave,
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noclearbuff
    ]
  },
  %{
    :status => :madogear,
    :icon => :efst_madogear_type,
    :calc_flags => [:speed],
    :flags => [
      :displaypc,
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noclearbuff,
      :sendval1
    ],
    :end_on_start => [
      :shapeshift,
      :hovering,
      :acceleration,
      :overheat_limitpoint,
      :overheat,
      :magneticfield,
      :neutralbarrier_master,
      :stealthfield_master
    ]
  },
  %{
    :status => :npc_hallucinationwalk,
    :icon => :efst_npc_hallucinationwalk,
    :duration_lookup => :npc_hallucinationwalk,
    :calc_flags => [:flee],
    :flags => [:sendval3]
  },
  %{
    :status => :packing_envelope1,
    :icon => :efst_packing_envelope1,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bBaseAtk, getstatus(SC_PACKING_ENVELOPE1, 1);
"
  },
  %{
    :status => :packing_envelope2,
    :icon => :efst_packing_envelope2,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bMatk, getstatus(SC_PACKING_ENVELOPE2, 1);
"
  },
  %{
    :status => :packing_envelope3,
    :icon => :efst_packing_envelope3,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bMaxHPrate, getstatus(SC_PACKING_ENVELOPE3, 1);
"
  },
  %{
    :status => :packing_envelope4,
    :icon => :efst_packing_envelope4,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bMaxSPrate, getstatus(SC_PACKING_ENVELOPE4, 1);
"
  },
  %{
    :status => :packing_envelope5,
    :icon => :efst_packing_envelope5,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bFlee, getstatus(SC_PACKING_ENVELOPE5, 1);
"
  },
  %{
    :status => :packing_envelope6,
    :icon => :efst_packing_envelope6,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bAspd, getstatus(SC_PACKING_ENVELOPE6, 1);
"
  },
  %{
    :status => :packing_envelope7,
    :icon => :efst_packing_envelope7,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bDef, getstatus(SC_PACKING_ENVELOPE7, 1);
"
  },
  %{
    :status => :packing_envelope8,
    :icon => :efst_packing_envelope8,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bMdef, getstatus(SC_PACKING_ENVELOPE8, 1);
"
  },
  %{
    :status => :packing_envelope9,
    :icon => :efst_packing_envelope9,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bCritical, getstatus(SC_PACKING_ENVELOPE9, 1);
"
  },
  %{
    :status => :packing_envelope10,
    :icon => :efst_packing_envelope10,
    :flags => [
      :noremoveondead,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :script => "bonus bHit, getstatus(SC_PACKING_ENVELOPE10, 1);
"
  },
  %{
    :status => :soulattack,
    :icon => :efst_soulattack,
    :flags => [
      :displaypc,
      :noremoveondead,
      :noclearbuff
    ]
  },
  %{
    :status => :wideweb,
    :icon => :efst_wideweb,
    :duration_lookup => :npc_wideweb,
    :calc_flags => [:flee],
    :flags => [:stopwalking]
  },
  %{
    :status => :burnt,
    :icon => :efst_burnt,
    :duration_lookup => :npc_firestorm,
    :flags => [:bleffect],
    :fail => [:chill]
  },
  %{
    :status => :chill,
    :icon => :efst_chill,
    :end_on_start => [:burnt]
  },
  %{
    :status => :handicapstate_deepblind,
    :icon => :efst_handicapstate_deepblind,
    :duration_lookup => :dk_servant_w_phantom,
    :calc_flags => [
      :flee,
      :flee2
    ],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :handicapstate_deepsilence,
    :icon => :efst_handicapstate_deepsilence,
    :duration_lookup => :cd_arbitrium,
    :calc_flags => [:aspd],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :handicapstate_lassitude,
    :calc_flags => [
      :speed,
      :cri
    ],
    :flags => [:displaypc]
  },
  %{
    :status => :handicapstate_frostbite,
    :icon => :efst_handicapstate_frostbite,
    :duration_lookup => :em_diamond_storm,
    :states => [:noconsumeitem],
    :calc_flags => [
      :def,
      :mdef,
      :def_ele
    ],
    :flags => [
      :bleffect,
      :displaypc,
      :removeondamaged
    ]
  },
  %{
    :status => :handicapstate_swooning,
    :icon => :efst_handicapstate_swooning,
    :states => [:noconsumeitem],
    :flags => [
      :displaypc,
      :removeondamaged
    ]
  },
  %{
    :status => :handicapstate_lightningstrike,
    :icon => :efst_handicapstate_lightningstrike,
    :duration_lookup => :em_lightning_land,
    :states => [:noconsumeitem],
    :calc_flags => [:def_ele],
    :flags => [
      :bleffect,
      :displaypc,
      :removeondamaged
    ]
  },
  %{
    :status => :handicapstate_crystallization,
    :icon => :efst_handicapstate_crystallization,
    :duration_lookup => :em_terra_drive,
    :states => [:noconsumeitem],
    :calc_flags => [
      :mdef,
      :def_ele
    ],
    :flags => [
      :bleffect,
      :displaypc,
      :removeondamaged
    ]
  },
  %{
    :status => :handicapstate_conflagration,
    :icon => :efst_handicapstate_conflagration,
    :duration_lookup => :em_conflagration,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :handicapstate_misfortune,
    :icon => :efst_handicapstate_misfortune,
    :duration_lookup => :abc_unlucky_rush,
    :calc_flags => [:hit],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :handicapstate_deadlypoison,
    :icon => :efst_handicapstate_deadlypoison,
    :duration_lookup => :em_venom_swamp,
    :calc_flags => [:def],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :handicapstate_depression,
    :icon => :efst_handicapstate_depression,
    :flags => [:displaypc]
  },
  %{
    :status => :handicapstate_holyflame,
    :icon => :efst_handicapstate_holyflame,
    :flags => [:displaypc]
  },
  %{
    :status => :servantweapon,
    :icon => :efst_servantweapon,
    :duration_lookup => :dk_servantweapon,
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :servant_sign,
    :icon => :efst_servant_sign,
    :duration_lookup => :dk_servant_w_sign,
    :flags => [
      :bleffect,
      :displaypc,
      :overlapignorelevel,
      :removeonchangemap,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :chargingpierce,
    :icon => :efst_chargingpierce,
    :duration_lookup => :dk_chargingpierce,
    :flags => [:sendval1],
    :end_on_end => [:chargingpierce_count]
  },
  %{
    :status => :chargingpierce_count,
    :icon => :efst_chargingpierce_count,
    :flags => [
      :sendval1,
      :displaypc
    ]
  },
  %{
    :status => :dragonic_aura,
    :icon => :efst_dragonic_aura,
    :duration_lookup => :dk_dragonic_aura,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :vigor,
    :icon => :efst_vigor,
    :duration_lookup => :dk_vigor,
    :calc_flags => [:all],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :deadly_defeasance,
    :icon => :efst_deadly_defeasance,
    :duration_lookup => :ag_deadly_projection,
    :calc_flags => [:all],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :climax_des_hu,
    :icon => :efst_climax_des_hu,
    :duration_lookup => :ag_destructive_hurricane,
    :calc_flags => [:matk]
  },
  %{
    :status => :climax,
    :icon => :efst_climax,
    :duration_lookup => :ag_climax,
    :calc_flags => [:all],
    :flags => [
      :bleffect,
      :displaypc,
      :overlapignorelevel,
      :sendval1
    ]
  },
  %{
    :status => :climax_earth,
    :icon => :efst_climax_earth,
    :duration_lookup => :ag_violent_quake,
    :calc_flags => [:all]
  },
  %{
    :status => :climax_bloom,
    :icon => :efst_climax_bloom,
    :duration_lookup => :ag_all_bloom,
    :calc_flags => [:all]
  },
  %{
    :status => :climax_cryimp,
    :icon => :efst_climax_cryimp,
    :duration_lookup => :ag_crystal_impact,
    :calc_flags => [:all]
  },
  %{
    :status => :windsign,
    :icon => :efst_windsign,
    :duration_lookup => :wh_wind_sign,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :crescivebolt,
    :icon => :efst_crescivebolt,
    :duration_lookup => :wh_crescive_bolt
  },
  %{
    :status => :calamitygale,
    :icon => :efst_calamitygale,
    :duration_lookup => :wh_calamitygale,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :mediale,
    :icon => :efst_mediale,
    :duration_lookup => :cd_mediale_votum,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :a_vita,
    :icon => :efst_a_vita,
    :duration_lookup => :cd_argutus_vita
  },
  %{
    :status => :a_telum,
    :icon => :efst_a_telum,
    :duration_lookup => :cd_argutus_telum
  },
  %{
    :status => :pre_acies,
    :icon => :efst_pre_acies,
    :duration_lookup => :cd_presens_acies,
    :calc_flags => [:crate],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :competentia,
    :icon => :efst_competentia,
    :duration_lookup => :cd_competentia,
    :calc_flags => [
      :patk,
      :smatk
    ],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :religio,
    :icon => :efst_religio,
    :duration_lookup => :cd_religio,
    :calc_flags => [
      :sta,
      :wis,
      :spl
    ],
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [:sandy_festival]
  },
  %{
    :status => :benedictum,
    :icon => :efst_benedictum,
    :duration_lookup => :cd_benedictum,
    :calc_flags => [
      :pow,
      :con,
      :crt
    ],
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [:marine_festival]
  },
  %{
    :status => :axe_stomp,
    :icon => :efst_axe_stomp,
    :duration_lookup => :mt_axe_stomp
  },
  %{
    :status => :a_machine,
    :icon => :efst_a_machine,
    :duration_lookup => :mt_a_machine,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :d_machine,
    :icon => :efst_d_machine,
    :duration_lookup => :mt_d_machine,
    :calc_flags => [
      :def,
      :res
    ],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :abr_battle_warior,
    :icon => :efst_abr_battle_warior,
    :duration_lookup => :mt_summon_abr_battle_warior
  },
  %{
    :status => :abr_dual_cannon,
    :icon => :efst_abr_dual_cannon,
    :duration_lookup => :mt_summon_abr_dual_cannon
  },
  %{
    :status => :abr_mother_net,
    :icon => :efst_abr_mother_net,
    :duration_lookup => :mt_summon_abr_mother_net
  },
  %{
    :status => :abr_infinity,
    :icon => :efst_abr_infinity,
    :duration_lookup => :mt_summon_abr_infinity
  },
  %{
    :status => :shadow_exceed,
    :icon => :efst_shadow_exceed,
    :duration_lookup => :shc_shadow_exceed,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :dancing_knife,
    :icon => :efst_dancing_knife,
    :duration_lookup => :shc_dancing_knife,
    :flags => [
      :bleffect,
      :displaypc,
      :requireweapon
    ]
  },
  %{
    :status => :potent_venom,
    :icon => :efst_potent_venom,
    :duration_lookup => :shc_potent_venom
  },
  %{
    :status => :shadow_scar,
    :icon => :efst_shadow_scar
  },
  %{
    :status => :e_slash_count,
    :icon => :efst_e_slash_count,
    :duration_lookup => :shc_eternal_slash,
    :flags => [
      :bleffect,
      :displaypc,
      :sendval1,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :shadow_weapon,
    :icon => :efst_shadow_weapon,
    :duration_lookup => :shc_enchanting_shadow
  },
  %{
    :status => :guard_stance,
    :icon => :efst_guard_stance,
    :duration_lookup => :ig_guard_stance,
    :calc_flags => [
      :watk,
      :def
    ],
    :flags => [
      :noremoveondead,
      :nosave,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :end_on_start => [:attack_stance]
  },
  %{
    :status => :attack_stance,
    :icon => :efst_attack_stance,
    :duration_lookup => :ig_attack_stance,
    :calc_flags => [
      :watk,
      :def
    ],
    :flags => [
      :noremoveondead,
      :nosave,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ],
    :end_on_start => [:guard_stance]
  },
  %{
    :status => :guardian_s,
    :icon => :efst_guardian_s,
    :duration_lookup => :ig_guardian_shield
  },
  %{
    :status => :rebound_s,
    :icon => :efst_rebound_s,
    :duration_lookup => :ig_rebound_shield
  },
  %{
    :status => :holy_s,
    :icon => :efst_holy_s,
    :duration_lookup => :ig_holy_shield,
    :calc_flags => [:all],
    :flags => [
      :bleffect,
      :displaypc,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :ultimate_s,
    :icon => :efst_ultimate_s,
    :duration_lookup => :ig_ultimate_sacrifice
  },
  %{
    :status => :spear_scar,
    :icon => :efst_spear_scar,
    :duration_lookup => :ig_grand_judgement,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :shield_power,
    :icon => :efst_shield_power,
    :duration_lookup => :ig_shield_shooting
  },
  %{
    :status => :spell_enchanting,
    :icon => :efst_spell_enchanting,
    :duration_lookup => :em_spell_enchanting,
    :calc_flags => [:smatk],
    :flags => [:displaypc]
  },
  %{
    :status => :summon_elemental_ardor,
    :icon => :efst_summon_elemental_ardor,
    :duration_lookup => :em_summon_elemental_ardor
  },
  %{
    :status => :summon_elemental_diluvio,
    :icon => :efst_summon_elemental_diluvio,
    :duration_lookup => :em_summon_elemental_diluvio
  },
  %{
    :status => :summon_elemental_procella,
    :icon => :efst_summon_elemental_procella,
    :duration_lookup => :em_summon_elemental_procella
  },
  %{
    :status => :summon_elemental_terremotus,
    :icon => :efst_summon_elemental_terremotus,
    :duration_lookup => :em_summon_elemental_terremotus
  },
  %{
    :status => :summon_elemental_serpens,
    :icon => :efst_summon_elemental_serpens,
    :duration_lookup => :em_summon_elemental_serpens
  },
  %{
    :status => :elemental_veil,
    :icon => :efst_elemental_veil,
    :duration_lookup => :em_elemental_veil,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :mystic_symphony,
    :icon => :efst_mystic_symphony,
    :duration_lookup => :tr_mystic_symphony,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :kvasir_sonata,
    :icon => :efst_kvasir_sonata,
    :duration_lookup => :tr_kvasir_sonata
  },
  %{
    :status => :soundblend,
    :icon => :efst_soundblend,
    :duration_lookup => :tr_soundblend,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :gef_nocturn,
    :icon => :efst_gef_nocturn,
    :duration_lookup => :tr_gef_nocturn,
    :calc_flags => [:mres]
  },
  %{
    :status => :ain_rhapsody,
    :icon => :efst_ain_rhapsody,
    :duration_lookup => :tr_ain_rhapsody,
    :calc_flags => [:res]
  },
  %{
    :status => :musical_interlude,
    :icon => :efst_musical_interlude,
    :duration_lookup => :tr_musical_interlude,
    :calc_flags => [:res],
    :flags => [:displaypc]
  },
  %{
    :status => :jawaii_serenade,
    :icon => :efst_jawaii_serenade,
    :duration_lookup => :tr_jawaii_serenade,
    :calc_flags => [
      :smatk,
      :speed
    ],
    :flags => [:displaypc]
  },
  %{
    :status => :pron_march,
    :icon => :efst_pron_march,
    :duration_lookup => :tr_pron_march,
    :calc_flags => [:patk],
    :flags => [:displaypc]
  },
  %{
    :status => :roseblossom,
    :icon => :efst_roseblossom,
    :duration_lookup => :tr_roseblossom
  },
  %{
    :status => :powerful_faith,
    :icon => :efst_powerful_faith,
    :duration_lookup => :iq_powerful_faith,
    :calc_flags => [
      :watk,
      :patk
    ],
    :flags => [:displaypc],
    :end_on_start => [
      :powerful_faith,
      :firm_faith,
      :sincere_faith
    ]
  },
  %{
    :status => :sincere_faith,
    :icon => :efst_sincere_faith,
    :duration_lookup => :iq_sincere_faith,
    :calc_flags => [:all],
    :end_on_start => [
      :powerful_faith,
      :firm_faith,
      :sincere_faith
    ]
  },
  %{
    :status => :firm_faith,
    :icon => :efst_firm_faith,
    :duration_lookup => :iq_firm_faith,
    :calc_flags => [
      :maxhp,
      :res
    ],
    :end_on_start => [
      :powerful_faith,
      :firm_faith,
      :sincere_faith
    ]
  },
  %{
    :status => :holy_oil,
    :icon => :efst_holy_oil,
    :duration_lookup => :iq_oleum_sanctum,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :first_brand,
    :icon => :efst_first_brand,
    :duration_lookup => :iq_first_brand,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :first_brand,
      :second_brand
    ]
  },
  %{
    :status => :second_brand,
    :icon => :efst_second_brand,
    :duration_lookup => :iq_second_flame,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :first_brand,
      :second_brand
    ]
  },
  %{
    :status => :second_judge,
    :icon => :efst_second_judge,
    :duration_lookup => :iq_judge,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :first_faith_power,
      :second_judge,
      :third_exor_flame
    ]
  },
  %{
    :status => :third_exor_flame,
    :icon => :efst_third_exor_flame,
    :duration_lookup => :iq_third_exor_flame,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :first_faith_power,
      :second_judge,
      :third_exor_flame
    ]
  },
  %{
    :status => :first_faith_power,
    :icon => :efst_first_faith_power,
    :duration_lookup => :iq_first_faith_power,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :first_faith_power,
      :second_judge,
      :third_exor_flame
    ]
  },
  %{
    :status => :massive_f_blaster,
    :icon => :efst_massive_f_blaster,
    :duration_lookup => :iq_massive_f_blaster
  },
  %{
    :status => :protectshadowequip,
    :icon => :efst_protectshadowequip,
    :duration_lookup => :bo_advance_protection,
    :flags => [
      :removechemicalprotect,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :researchreport,
    :icon => :efst_researchreport,
    :duration_lookup => :bo_researchreport
  },
  %{
    :status => :bo_hell_dusty,
    :icon => :efst_bo_hell_dusty
  },
  %{
    :status => :bionic_woodenwarrior,
    :duration_lookup => :bo_woodenwarrior
  },
  %{
    :status => :bionic_wooden_fairy,
    :duration_lookup => :bo_wooden_fairy
  },
  %{
    :status => :bionic_creeper,
    :duration_lookup => :bo_creeper
  },
  %{
    :status => :bionic_helltree,
    :duration_lookup => :bo_helltree
  },
  %{
    :status => :shadow_strip,
    :icon => :efst_shadow_strip,
    :duration_lookup => :abc_strip_shadow,
    :calc_flags => [
      :res,
      :mres
    ],
    :flags => [
      :bossresist,
      :noclearbuff,
      :debuff,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :abyss_dagger,
    :icon => :efst_abyss_dagger,
    :duration_lookup => :abc_abyss_dagger
  },
  %{
    :status => :abyssforceweapon,
    :icon => :efst_abyssforceweapon,
    :duration_lookup => :abc_from_the_abyss,
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :abyss_slayer,
    :icon => :efst_abyss_slayer,
    :duration_lookup => :abc_abyss_slayer,
    :calc_flags => [
      :hit,
      :patk,
      :smatk
    ],
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :flametechnic,
    :icon => :efst_flametechnic,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :flametechnic_option,
    :icon => :efst_flametechnic_option,
    :duration_lookup => :em_el_flametechnic,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :flamearmor,
    :icon => :efst_flamearmor,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :flamearmor_option,
    :icon => :efst_flamearmor_option,
    :duration_lookup => :em_el_flamearmor,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :cold_force,
    :icon => :efst_cold_force,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :cold_force_option,
    :icon => :efst_cold_force_option,
    :duration_lookup => :em_el_cold_force,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :crystal_armor,
    :icon => :efst_crystal_armor,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :crystal_armor_option,
    :icon => :efst_crystal_armor_option,
    :duration_lookup => :em_el_crystal_armor,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :grace_breeze,
    :icon => :efst_grace_breeze,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :grace_breeze_option,
    :icon => :efst_grace_breeze_option,
    :duration_lookup => :em_el_grace_breeze,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :eyes_of_storm,
    :icon => :efst_eyes_of_storm,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :eyes_of_storm_option,
    :icon => :efst_eyes_of_storm_option,
    :duration_lookup => :em_el_eyes_of_storm,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :earth_care,
    :icon => :efst_earth_care,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :earth_care_option,
    :icon => :efst_earth_care_option,
    :duration_lookup => :em_el_earth_care,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :strong_protection,
    :icon => :efst_strong_protection,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :strong_protection_option,
    :icon => :efst_strong_protection_option,
    :duration_lookup => :em_el_strong_protection,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :deep_poisoning,
    :icon => :efst_deep_poisoning,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :deep_poisoning_option,
    :icon => :efst_deep_poisoning_option,
    :duration_lookup => :em_el_deep_poisoning,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :poison_shield,
    :icon => :efst_poison_shield,
    :flags => [:removeelementaloption]
  },
  %{
    :status => :poison_shield_option,
    :icon => :efst_poison_shield_option,
    :duration_lookup => :em_el_poison_shield,
    :calc_flags => [:all],
    :flags => [:removeelementaloption]
  },
  %{
    :status => :m_lifepotion,
    :icon => :efst_m_lifepotion,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "if (!getstatus(SC_BERSERK)) {
   .@val1 = -getstatus(SC_M_LIFEPOTION, 1);
   .@val2 = getstatus(SC_M_LIFEPOTION, 2) * 1000;
   bonus2 bRegenPercentHP, .@val1, .@val2;
}
"
  },
  %{
    :status => :s_manapotion,
    :icon => :efst_s_manapotion,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "if (!getstatus(SC_BERSERK)) {
   .@val1 = -getstatus(SC_S_MANAPOTION, 1);
   .@val2 = getstatus(SC_S_MANAPOTION, 2);
   bonus2 bRegenPercentSP, .@val1, 1000*.@val2;
}
"
  },
  %{
    :status => :sub_weaponproperty,
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance,
      :noremoveondead,
      :noclearbuff
    ],
    :end_on_start => [:sub_weaponproperty]
  },
  %{
    :status => :almighty,
    :icon => :efst_almighty,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:ultimatecook],
    :script => ".@val1 = getstatus(SC_ALMIGHTY, 1);
bonus bMatk, .@val1;
bonus bBaseAtk, .@val1;
"
  },
  %{
    :status => :ultimatecook,
    :icon => :efst_ultimatecook,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :food_str_cash,
      :food_agi_cash,
      :food_vit_cash,
      :food_int_cash,
      :food_dex_cash,
      :food_luk_cash,
      :almighty
    ],
    :script => "bonus bAllStats, getstatus(SC_ULTIMATECOOK, 1);
bonus bMatk,30;
bonus bBaseAtk,30;
"
  },
  %{
    :status => :m_defscroll,
    :icon => :efst_m_defscroll,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bDef, getstatus(SC_M_DEFSCROLL, 1);
bonus bMdef, getstatus(SC_M_DEFSCROLL, 2);
"
  },
  %{
    :status => :infinity_drink,
    :icon => :efst_infinity_drink,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bCritAtkRate,5;
bonus bLongAtkRate,5;
bonus2 bMagicAtkEle,Ele_All,5;
bonus bMaxHPrate,5;
bonus bMaxSPrate,5;
bonus bNoCastCancel;
"
  },
  %{
    :status => :mental_potion,
    :icon => :efst_target_aspd,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_MENTAL_POTION, 1);
bonus bMaxSPrate, .@val1;
bonus bUseSPrate, -.@val1;
"
  },
  %{
    :status => :limit_power_booster,
    :icon => :efst_limit_power_booster,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_LIMIT_POWER_BOOSTER, 1);
.@val2 = getstatus(SC_LIMIT_POWER_BOOSTER, 2);
.@val3 = getstatus(SC_LIMIT_POWER_BOOSTER, 3);
bonus bBaseAtk, .@val1;
bonus bMatk, .@val1;
bonus bHit, .@val1;
bonus bFlee, .@val1;
bonus bFixedCastrate, -.@val1;
bonus bAtkRate, .@val2;
bonus bMatkRate, .@val2;
bonus bAspd, .@val2;
bonus bUseSPrate, .@val3;
"
  },
  %{
    :status => :combat_pill,
    :icon => :efst_gm_battle,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_COMBAT_PILL, 1);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
bonus bMaxHPrate,-3;
bonus bMaxSPrate,-3;
"
  },
  %{
    :status => :combat_pill2,
    :icon => :efst_gm_battle2,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_COMBAT_PILL2, 1);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
bonus bMaxHPrate,-5;
bonus bMaxSPrate,-5;
"
  },
  %{
    :status => :mysticpowder,
    :icon => :efst_mysticpowder,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bFlee,20;
bonus bLuk,10;
"
  },
  %{
    :status => :sparkcandy,
    :icon => :efst_steampack,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bBaseAtk,20;
bonus bAspdRate,25;
bonus bNoWalkDelay;
bonus2 bHPLossRate,100,10000;
"
  },
  %{
    :status => :magiccandy,
    :icon => :efst_magic_candy,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bMatk,30;
bonus bFixedCastrate,-70;
bonus bNoCastCancel;
bonus2 bSPLossRate,90,10000;
"
  },
  %{
    :status => :acaraje,
    :icon => :efst_acaraje,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bAspdRate, getstatus(SC_ACARAJE, 1);
bonus bHit, getstatus(SC_ACARAJE, 2);
"
  },
  %{
    :status => :popecookie,
    :icon => :efst_popecookie,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_POPECOOKIE, 1);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
bonus2 bSubEle,Ele_All, .@val1;
"
  },
  %{
    :status => :vitalize_potion,
    :icon => :efst_vitalize_potion,
    :flags => [
      :noclearbuff,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_VITALIZE_POTION, 1);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
bonus bHealPower2,10;
bonus bAddItemHealRate,10;
"
  },
  %{
    :status => :cup_of_boza,
    :icon => :efst_cup_of_boza,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bVit,10;
bonus2 bSubEle,Ele_Fire,5;
"
  },
  %{
    :status => :skf_matk,
    :icon => :efst_skf_matk,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bMatk, getstatus(SC_SKF_MATK, 1);
"
  },
  %{
    :status => :skf_atk,
    :icon => :efst_skf_atk,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bBaseAtk, getstatus(SC_SKF_ATK, 1);
"
  },
  %{
    :status => :skf_aspd,
    :icon => :efst_skf_aspd,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bAspdRate, getstatus(SC_SKF_ASPD, 1);
"
  },
  %{
    :status => :skf_cast,
    :icon => :efst_skf_cast,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bVariableCastrate, getstatus(SC_SKF_CAST, 1);
"
  },
  %{
    :status => :beef_rib_stew,
    :icon => :efst_beef_rib_stew,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bVariableCastrate,-5;
bonus bUseSPrate,-3;
"
  },
  %{
    :status => :pork_rib_stew,
    :icon => :efst_pork_rib_stew,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bAspdRate,5;
bonus bUseSPrate,-2;
"
  },
  %{
    :status => :weaponbreaker,
    :duration_lookup => :npc_weaponbraker
  },
  %{
    :status => :tempering,
    :icon => :efst_tempering,
    :duration_lookup => :mh_tempering,
    :calc_flags => [:patk]
  },
  %{
    :status => :goldene_tone,
    :icon => :efst_goldene_tone,
    :duration_lookup => :mh_goldene_tone,
    :calc_flags => [
      :res,
      :mres
    ]
  },
  %{
    :status => :toxin_of_mandara,
    :icon => :efst_toxin_of_mandara,
    :duration_lookup => :mh_toxin_of_mandara,
    :calc_flags => [:res],
    :flags => [:debuff]
  },
  %{
    :status => :gradual_gravity,
    :icon => :efst_gradual_gravity,
    :duration_lookup => :npc_gradual_gravity,
    :flags => [
      :bleffect,
      :displaypc,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :all_stat_down,
    :icon => :efst_all_stat_down,
    :duration_lookup => :npc_all_stat_down,
    :calc_flags => [
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk
    ],
    :flags => [
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :killing_aura,
    :icon => :efst_killing_aura,
    :duration_lookup => :npc_killing_aura,
    :flags => [
      :bleffect,
      :displaypc,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :damage_heal,
    :icon => :efst_damage_heal,
    :duration_lookup => :npc_damage_heal,
    :flags => [:nodispell]
  },
  %{
    :status => :immune_property_nothing,
    :icon => :efst_immune_property_nothing,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_water,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_water,
    :icon => :efst_immune_property_water,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_ground,
    :icon => :efst_immune_property_ground,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_fire,
    :icon => :efst_immune_property_fire,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_ground,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_wind,
    :icon => :efst_immune_property_wind,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_poison,
    :icon => :efst_immune_property_poison,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_saint,
    :icon => :efst_immune_property_saint,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_darkness,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_darkness,
    :icon => :efst_immune_property_darkness,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_telekinesis,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_telekinesis,
    :icon => :efst_immune_property_telekinesis,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_undead
    ]
  },
  %{
    :status => :immune_property_undead,
    :icon => :efst_immune_property_undead,
    :duration_lookup => :npc_immune_property,
    :flags => [
      :bleffect,
      :displaypc
    ],
    :end_on_start => [
      :immune_property_nothing,
      :immune_property_water,
      :immune_property_ground,
      :immune_property_fire,
      :immune_property_wind,
      :immune_property_poison,
      :immune_property_saint,
      :immune_property_darkness,
      :immune_property_telekinesis
    ]
  },
  %{
    :status => :relieve_on,
    :icon => :efst_relieve_damage,
    :duration_lookup => :npc_relieve_on,
    :flags => [
      :bleffect,
      :displaypc,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:relieve_off]
  },
  %{
    :status => :relieve_off,
    :duration_lookup => :npc_relieve_off,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:relieve_on]
  },
  %{
    :status => :rush_quake1,
    :icon => :efst_rush_quake1,
    :duration_lookup => :mt_rush_quake,
    :flags => [
      :bleffect,
      :debuff
    ]
  },
  %{
    :status => :rush_quake2,
    :icon => :efst_rush_quake2,
    :duration_lookup => :mt_rush_quake,
    :calc_flags => [:all],
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :g_lifepotion,
    :icon => :efst_g_lifepotion,
    :flags => [
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "if (!getstatus(SC_BERSERK)) {
   .@val1 = -getstatus(SC_G_LIFEPOTION, 1);
   .@val2 = getstatus(SC_G_LIFEPOTION, 2) * 1000;
   bonus2 bRegenPercentHP, .@val1, .@val2;
}
"
  },
  %{
    :status => :hnnoweapon,
    :icon => :efst_noequipweapon,
    :duration_lookup => :hn_doublebowlingbash
  },
  %{
    :status => :shieldchainrush,
    :icon => :efst_shieldchainrush,
    :duration_lookup => :hn_shield_chain_rush,
    :calc_flags => [:speed],
    :flags => [:bossresist]
  },
  %{
    :status => :mistyfrost,
    :icon => :efst_mistyfrost,
    :duration_lookup => :hn_jack_frost_nova,
    :flags => [:bossresist]
  },
  %{
    :status => :groundgravity,
    :icon => :efst_groundgravity,
    :duration_lookup => :hn_ground_gravitation,
    :calc_flags => [:speed],
    :flags => [:bossresist]
  },
  %{
    :status => :breakinglimit,
    :icon => :efst_breakinglimit,
    :duration_lookup => :hn_breakinglimit
  },
  %{
    :status => :rulebreak,
    :icon => :efst_rulebreak,
    :duration_lookup => :hn_rulebreak
  },
  %{
    :status => :intensive_aim,
    :icon => :efst_intensive_aim,
    :states => [:nomove],
    :calc_flags => [
      :batk,
      :hit,
      :cri
    ],
    :flags => [
      :bleffect,
      :displaypc,
      :sendval1,
      :nosave,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :intensive_aim_count,
    :icon => :efst_intensive_aim_count,
    :flags => [
      :displaypc,
      :sendval1,
      :nosave,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :grenade_fragment_1,
    :icon => :efst_grenade_fragment_1,
    :duration_lookup => :nw_grenade_fragment,
    :end_on_start => [
      :grenade_fragment_2,
      :grenade_fragment_3,
      :grenade_fragment_4,
      :grenade_fragment_5,
      :grenade_fragment_6
    ]
  },
  %{
    :status => :grenade_fragment_2,
    :icon => :efst_grenade_fragment_2,
    :duration_lookup => :nw_grenade_fragment,
    :end_on_start => [
      :grenade_fragment_1,
      :grenade_fragment_3,
      :grenade_fragment_4,
      :grenade_fragment_5,
      :grenade_fragment_6
    ]
  },
  %{
    :status => :grenade_fragment_3,
    :icon => :efst_grenade_fragment_3,
    :duration_lookup => :nw_grenade_fragment,
    :end_on_start => [
      :grenade_fragment_1,
      :grenade_fragment_2,
      :grenade_fragment_4,
      :grenade_fragment_5,
      :grenade_fragment_6
    ]
  },
  %{
    :status => :grenade_fragment_4,
    :icon => :efst_grenade_fragment_4,
    :duration_lookup => :nw_grenade_fragment,
    :end_on_start => [
      :grenade_fragment_1,
      :grenade_fragment_2,
      :grenade_fragment_3,
      :grenade_fragment_5,
      :grenade_fragment_6
    ]
  },
  %{
    :status => :grenade_fragment_5,
    :icon => :efst_grenade_fragment_5,
    :duration_lookup => :nw_grenade_fragment,
    :end_on_start => [
      :grenade_fragment_1,
      :grenade_fragment_2,
      :grenade_fragment_3,
      :grenade_fragment_4,
      :grenade_fragment_6
    ]
  },
  %{
    :status => :grenade_fragment_6,
    :icon => :efst_grenade_fragment_6,
    :duration_lookup => :nw_grenade_fragment,
    :end_on_start => [
      :grenade_fragment_1,
      :grenade_fragment_2,
      :grenade_fragment_3,
      :grenade_fragment_4,
      :grenade_fragment_5
    ]
  },
  %{
    :status => :auto_firing_launcher,
    :icon => :efst_auto_firing_launcherefst,
    :duration_lookup => :nw_auto_firing_launcher,
    :flags => [:sendval1]
  },
  %{
    :status => :hidden_card,
    :icon => :efst_hidden_card,
    :duration_lookup => :nw_hidden_card,
    :calc_flags => [:all],
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :period_receiveitem_2nd,
    :icon => :efst_period_receiveitem_2nd,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :period_plusexp_2nd,
    :icon => :efst_period_plusexp_2nd,
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :sendval1
    ]
  },
  %{
    :status => :powerup,
    :icon => :efst_powerup,
    :duration_lookup => :npc_powerup,
    :calc_flags => [:hit],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :agiup,
    :icon => :efst_agiup,
    :duration_lookup => :npc_agiup,
    :calc_flags => [
      :speed,
      :flee
    ],
    :flags => [
      :noclearbuff,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [:decreaseagi]
  },
  %{
    :status => :protection,
    :icon => :efst_ray_of_protection,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :stun,
      :sleep,
      :curse,
      :stone,
      :poison,
      :blind,
      :silence,
      :bleeding,
      :confusion,
      :freeze
    ]
  },
  %{
    :status => :bath_foam_a,
    :icon => :efst_bath_foam_a,
    :flags => [
      :nobanishingbuster,
      :noclearance,
      :noclearbuff,
      :nodispell
    ],
    :script => ".@val1 = getstatus(SC_BATH_FOAM_A, 1);
bonus2 bAddRace2, RC2_EP172BATH, .@val1;
bonus2 bMagicAddRace2, RC2_EP172BATH, .@val1;
"
  },
  %{
    :status => :bath_foam_b,
    :icon => :efst_bath_foam_b,
    :flags => [
      :nobanishingbuster,
      :noclearance,
      :noclearbuff,
      :nodispell
    ],
    :script => ".@val1 = getstatus(SC_BATH_FOAM_B, 1);
bonus2 bAddRace2, RC2_EP172BATH, .@val1;
bonus2 bMagicAddRace2, RC2_EP172BATH, .@val1;
"
  },
  %{
    :status => :bath_foam_c,
    :icon => :efst_bath_foam_c,
    :flags => [
      :nobanishingbuster,
      :noclearance,
      :noclearbuff,
      :nodispell
    ],
    :script => ".@val1 = getstatus(SC_BATH_FOAM_C, 1);
bonus2 bAddRace2, RC2_EP172BATH, .@val1;
bonus2 bMagicAddRace2, RC2_EP172BATH, .@val1;
"
  },
  %{
    :status => :buchedenoel,
    :icon => :efst_buchedenoel,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bHPrecovRate,3;
bonus bSPrecovRate,3;
bonus bHit,3;
bonus bCritical,7;
"
  },
  %{
    :status => :ep16_def,
    :icon => :efst_ep16_def,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :end_on_start => [
      :curse,
      :silence,
      :poison
    ],
    :script => "bonus2 bSubRace2,RC2_EP16_DEF, getstatus(SC_EP16_DEF, 1);
"
  },
  %{
    :status => :str_scroll,
    :icon => :efst_str_scroll,
    :flags => [
      :nobanishingbuster,
      :noclearbuff,
      :noclearance,
      :nodispell,
      :noremoveondead
    ],
    :script => "bonus bStr, getstatus(SC_STR_SCROLL, 1);
"
  },
  %{
    :status => :int_scroll,
    :icon => :efst_int_scroll,
    :flags => [
      :nobanishingbuster,
      :noclearbuff,
      :noclearance,
      :nodispell,
      :noremoveondead
    ],
    :script => "bonus bInt, getstatus(SC_INT_SCROLL, 1);
"
  },
  %{
    :status => :contents_1,
    :icon => :efst_contents_1,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_1, 1);
bonus2 bAddEle,Ele_All, .@val1;
bonus2 bMagicAddEle,Ele_All, .@val1;
"
  },
  %{
    :status => :contents_2,
    :icon => :efst_contents_2,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_2, 1);
bonus bShortAtkRate, .@val1;
bonus bLongAtkRate, .@val1;
bonus2 bMagicAtkEle,Ele_All, .@val1;
"
  },
  %{
    :status => :contents_3,
    :icon => :efst_contents_3,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_3, 1);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
"
  },
  %{
    :status => :contents_4,
    :icon => :efst_contents_4,
    :calc_flags => [:all],
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_4, 1);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
"
  },
  %{
    :status => :contents_5,
    :icon => :efst_contents_5,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_5, 1);
bonus bVariableCastrate, -.@val1;
bonus bAspdRate, .@val1;
"
  },
  %{
    :status => :contents_6,
    :icon => :efst_contents_6,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_6, 1);
bonus2 bAddRace,RC_Dragon, .@val1;
bonus2 bAddRace,RC_Plant, .@val1;
bonus2 bMagicAddRace,RC_Dragon, .@val1;
bonus2 bMagicAddRace,RC_Plant, .@val1;
"
  },
  %{
    :status => :contents_7,
    :icon => :efst_contents_7,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_7, 1);
bonus2 bAddRace,RC_Demon, .@val1;
bonus2 bAddRace,RC_Undead, .@val1;
bonus2 bMagicAddRace,RC_Demon, .@val1;
bonus2 bMagicAddRace,RC_Undead, .@val1;
"
  },
  %{
    :status => :contents_8,
    :icon => :efst_contents_8,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_8, 1);
bonus2 bAddRace,RC_Fish, .@val1;
bonus2 bAddRace,RC_Formless, .@val1;
bonus2 bMagicAddRace,RC_Fish, .@val1;
bonus2 bMagicAddRace,RC_Formless, .@val1;
"
  },
  %{
    :status => :contents_9,
    :icon => :efst_contents_9,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_9, 1);
bonus2 bAddRace,RC_Angel, .@val1;
bonus2 bAddRace,RC_Brute, .@val1;
bonus2 bMagicAddRace,RC_Angel, .@val1;
bonus2 bMagicAddRace,RC_Brute, .@val1;
"
  },
  %{
    :status => :contents_10,
    :icon => :efst_contents_10,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_10, 1);
bonus2 bAddRace,RC_DemiHuman, .@val1;
bonus2 bAddRace,RC_Insect, .@val1;
bonus2 bMagicAddRace,RC_DemiHuman, .@val1;
bonus2 bMagicAddRace,RC_Insect, .@val1;
"
  },
  %{
    :status => :mystery_powder,
    :icon => :efst_mystery_powder,
    :duration_lookup => :bo_mystery_powder,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :contents_26,
    :icon => :efst_contents_26,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_26, 1);
.@val2 = getstatus(SC_CONTENTS_26, 2);
bonus bHit, .@val1;
bonus2 bAddEle,Ele_All, .@val2;
bonus2 bMagicAddEle,Ele_All, .@val2;
"
  },
  %{
    :status => :contents_27,
    :icon => :efst_contents_27,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_27, 1);
.@val2 = getstatus(SC_CONTENTS_27, 2);
bonus bCritical, .@val1;
bonus2 bAddSize,Size_All, .@val2;
bonus2 bMagicAddSize,Size_All, .@val2;
"
  },
  %{
    :status => :contents_28,
    :icon => :efst_contents_28,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_28, 1);
.@val2 = getstatus(SC_CONTENTS_28, 2);
bonus bFlee, .@val1;
bonus bShortAtkRate, .@val2;
bonus bLongAtkRate, .@val2;
bonus2 bMagicAtkEle,Ele_All, .@val2;
"
  },
  %{
    :status => :contents_29,
    :icon => :efst_contents_29,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_29, 1);
.@val2 = getstatus(SC_CONTENTS_29, 2);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
bonus bVariableCastrate, .@val2;
"
  },
  %{
    :status => :contents_31,
    :icon => :efst_contents_31,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_31, 1);
bonus2 bAddSize,Size_All, .@val1;
bonus2 bMagicAddSize,Size_All, .@val1;
bonus2 bAddEle,Ele_All, .@val1;
bonus2 bMagicAddEle,Ele_All, .@val1;
"
  },
  %{
    :status => :contents_32,
    :icon => :efst_contents_32,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_32, 1);
bonus2 bMagicAtkEle,Ele_All, .@val1;
bonus bShortAtkRate, .@val1;
bonus bLongAtkRate, .@val1;
bonus bMatkRate, .@val1;
bonus bAtkRate, .@val1;
"
  },
  %{
    :status => :contents_33,
    :icon => :efst_contents_33,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_33, 1);
bonus bVariableCastrate, -.@val1;
bonus bMaxHPrate, .@val1;
bonus bMaxSPrate, .@val1;
"
  },
  %{
    :status => :talisman_of_protection,
    :icon => :efst_talisman_of_protection,
    :duration_lookup => :soa_talisman_of_protection,
    :flags => [
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :talisman_of_warrior,
    :icon => :efst_talisman_of_warrior,
    :duration_lookup => :soa_talisman_of_warrior,
    :calc_flags => [:patk],
    :flags => [
      :bleffect,
      :displaypc,
      :requireweapon
    ]
  },
  %{
    :status => :talisman_of_magician,
    :icon => :efst_talisman_of_magician,
    :duration_lookup => :soa_talisman_of_magician,
    :calc_flags => [:smatk],
    :flags => [
      :bleffect,
      :displaypc,
      :requireweapon
    ]
  },
  %{
    :status => :talisman_of_five_elements,
    :icon => :efst_talisman_of_five_elements,
    :duration_lookup => :soa_talisman_of_five_elements,
    :calc_flags => [:all],
    :flags => [
      :bleffect,
      :displaypc,
      :requireweapon
    ]
  },
  %{
    :status => :totem_of_tutelary,
    :icon => :efst_blank,
    :duration_lookup => :soa_totem_of_tutelary,
    :calc_flags => [:regen]
  },
  %{
    :status => :t_first_god,
    :icon => :efst_t_first_god,
    :duration_lookup => :soa_talisman_of_blue_dragon,
    :fail => [
      :t_second_god,
      :t_third_god,
      :t_fourth_god,
      :t_fifth_god
    ]
  },
  %{
    :status => :t_second_god,
    :icon => :efst_t_second_god,
    :duration_lookup => :soa_talisman_of_white_tiger,
    :fail => [:t_second_god],
    :end_on_start => [:t_first_god]
  },
  %{
    :status => :t_third_god,
    :icon => :efst_t_third_god,
    :duration_lookup => :soa_talisman_of_red_phoenix,
    :fail => [:t_third_god],
    :end_on_start => [:t_second_god]
  },
  %{
    :status => :t_fourth_god,
    :icon => :efst_t_fourth_god,
    :duration_lookup => :soa_talisman_of_black_tortoise,
    :fail => [:t_fourth_god],
    :end_on_start => [:t_third_god]
  },
  %{
    :status => :t_fifth_god,
    :icon => :efst_t_fiveth_god,
    :duration_lookup => :soa_circle_of_directions_and_elementals,
    :calc_flags => [:smatk],
    :flags => [
      :nobanishingbuster,
      :noclearance,
      :nodispell
    ],
    :end_on_start => [:t_fourth_god]
  },
  %{
    :status => :heaven_and_earth,
    :icon => :efst_heaven_and_earth,
    :duration_lookup => :soa_soul_of_heaven_and_earth,
    :calc_flags => [:all]
  },
  %{
    :status => :return_to_eldicastes,
    :icon => :efst_return_to_eldicastes,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :guardian_recall,
    :icon => :efst_guardian_recall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :eclage_recall,
    :icon => :efst_eclage_recall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :all_niflheim_recall,
    :icon => :efst_all_niflheim_recall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :all_prontera_recall,
    :icon => :efst_all_prontera_recall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :all_glastheim_recall,
    :icon => :efst_all_glastheim_recall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :all_thanatos_recall,
    :icon => :efst_all_thanatos_recall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :all_lighthalzen_recall,
    :icon => :efst_all_lighthalzen_recall,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ]
  },
  %{
    :status => :hogogong,
    :icon => :efst_hogogong,
    :duration_lookup => :sh_howling_of_chul_ho,
    :flags => [
      :debuff,
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :temporary_communion,
    :icon => :efst_temporary_communion,
    :duration_lookup => :sh_temporary_communion,
    :calc_flags => [
      :patk,
      :smatk,
      :hplus
    ],
    :flags => [:nodispell]
  },
  %{
    :status => :marine_festival,
    :icon => :efst_marine_festival,
    :duration_lookup => :sh_marine_festival_of_ki_sul,
    :calc_flags => [
      :pow,
      :con,
      :crt
    ],
    :end_on_start => [:benedictum]
  },
  %{
    :status => :sandy_festival,
    :icon => :efst_sandy_festival,
    :duration_lookup => :sh_sandy_festival_of_ki_sul,
    :calc_flags => [
      :spl,
      :wis,
      :sta
    ],
    :end_on_start => [:religio]
  },
  %{
    :status => :ki_sul_rampage,
    :icon => :efst_ki_sul_rampage,
    :duration_lookup => :sh_ki_sul_rampage,
    :states => [:nocast]
  },
  %{
    :status => :colors_of_hyun_rok_buff,
    :icon => :efst_colors_of_hyun_rok_buff,
    :duration_lookup => :sh_colors_of_hyun_rok
  },
  %{
    :status => :colors_of_hyun_rok_1,
    :icon => :efst_colors_of_hyun_rok_1,
    :duration_lookup => :sh_colors_of_hyun_rok,
    :end_on_start => [
      :colors_of_hyun_rok_2,
      :colors_of_hyun_rok_3,
      :colors_of_hyun_rok_4,
      :colors_of_hyun_rok_5,
      :colors_of_hyun_rok_6
    ]
  },
  %{
    :status => :colors_of_hyun_rok_2,
    :icon => :efst_colors_of_hyun_rok_2,
    :duration_lookup => :sh_colors_of_hyun_rok,
    :end_on_start => [
      :colors_of_hyun_rok_1,
      :colors_of_hyun_rok_3,
      :colors_of_hyun_rok_4,
      :colors_of_hyun_rok_5,
      :colors_of_hyun_rok_6
    ]
  },
  %{
    :status => :colors_of_hyun_rok_3,
    :icon => :efst_colors_of_hyun_rok_3,
    :duration_lookup => :sh_colors_of_hyun_rok,
    :end_on_start => [
      :colors_of_hyun_rok_1,
      :colors_of_hyun_rok_2,
      :colors_of_hyun_rok_4,
      :colors_of_hyun_rok_5,
      :colors_of_hyun_rok_6
    ]
  },
  %{
    :status => :colors_of_hyun_rok_4,
    :icon => :efst_colors_of_hyun_rok_4,
    :duration_lookup => :sh_colors_of_hyun_rok,
    :end_on_start => [
      :colors_of_hyun_rok_1,
      :colors_of_hyun_rok_2,
      :colors_of_hyun_rok_3,
      :colors_of_hyun_rok_5,
      :colors_of_hyun_rok_6
    ]
  },
  %{
    :status => :colors_of_hyun_rok_5,
    :icon => :efst_colors_of_hyun_rok_5,
    :duration_lookup => :sh_colors_of_hyun_rok,
    :end_on_start => [
      :colors_of_hyun_rok_1,
      :colors_of_hyun_rok_2,
      :colors_of_hyun_rok_3,
      :colors_of_hyun_rok_4,
      :colors_of_hyun_rok_6
    ]
  },
  %{
    :status => :colors_of_hyun_rok_6,
    :icon => :efst_colors_of_hyun_rok_6,
    :duration_lookup => :sh_colors_of_hyun_rok,
    :end_on_start => [
      :colors_of_hyun_rok_1,
      :colors_of_hyun_rok_2,
      :colors_of_hyun_rok_3,
      :colors_of_hyun_rok_4,
      :colors_of_hyun_rok_5
    ]
  },
  %{
    :status => :blessing_of_m_creatures,
    :icon => :efst_blessing_of_m_creatures,
    :duration_lookup => :sh_blessing_of_mystical_creatures,
    :calc_flags => [
      :patk,
      :smatk
    ]
  },
  %{
    :status => :blessing_of_m_c_debuff,
    :icon => :efst_blessing_of_m_c_debuff,
    :duration_lookup => :sh_blessing_of_mystical_creatures,
    :flags => [:nodispell]
  },
  %{
    :status => :rising_sun,
    :icon => :efst_rising_sun,
    :duration_lookup => :ske_rising_sun,
    :fail => [
      :rising_moon,
      :midnight_moon,
      :sky_enchant
    ],
    :end_on_start => [:dawn_moon]
  },
  %{
    :status => :noon_sun,
    :icon => :efst_noon_sun,
    :duration_lookup => :ske_rising_sun,
    :end_on_start => [:rising_sun]
  },
  %{
    :status => :sunset_sun,
    :icon => :efst_sunset_sun,
    :duration_lookup => :ske_rising_sun,
    :fail => [:sunset_sun],
    :end_on_start => [:noon_sun]
  },
  %{
    :status => :rising_moon,
    :icon => :efst_rising_moon,
    :duration_lookup => :ske_rising_moon,
    :fail => [
      :rising_sun,
      :noon_sun,
      :sky_enchant
    ],
    :end_on_start => [:sunset_sun]
  },
  %{
    :status => :midnight_moon,
    :icon => :efst_midnight_moon,
    :duration_lookup => :ske_rising_moon,
    :end_on_start => [:rising_moon]
  },
  %{
    :status => :dawn_moon,
    :icon => :efst_dawn_moon,
    :duration_lookup => :ske_rising_moon,
    :fail => [:dawn_moon],
    :end_on_start => [:midnight_moon]
  },
  %{
    :status => :star_burst,
    :icon => :efst_star_burst,
    :duration_lookup => :ske_star_burst,
    :flags => [:bleffect]
  },
  %{
    :status => :sky_enchant,
    :icon => :efst_sky_enchant,
    :duration_lookup => :ske_enchanting_sky,
    :end_on_start => [
      :rising_sun,
      :noon_sun,
      :sunset_sun,
      :rising_moon,
      :midnight_moon,
      :dawn_moon
    ]
  },
  %{
    :status => :wild_walk,
    :icon => :efst_wild_walk,
    :duration_lookup => :wh_wild_walk,
    :calc_flags => [
      :flee,
      :speed
    ],
    :flags => [
      :noremoveondead,
      :nosave,
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  },
  %{
    :status => :shadow_clock,
    :icon => :efst_shadow_clock,
    :duration_lookup => :ss_tokedasu,
    :calc_flags => [:speed]
  },
  %{
    :status => :shinkirou_call,
    :icon => :efst_sbunshin,
    :duration_lookup => :ss_shinkirou,
    :calc_flags => [:speed]
  },
  %{
    :status => :nightmare,
    :icon => :efst_nightmare,
    :duration_lookup => :ss_kagegari,
    :flags => [
      :debuff,
      :bleffect,
      :displaypc
    ]
  },
  %{
    :status => :contents_34,
    :icon => :efst_contents_34,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bAspdRate, getstatus(SC_CONTENTS_34, 1);
bonus bCritical, getstatus(SC_CONTENTS_34, 2);
"
  },
  %{
    :status => :contents_35,
    :icon => :efst_contents_35,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_35, 1);
bonus bMatk, .@val1;
bonus bBaseAtk, .@val1;
"
  },
  %{
    :status => :noaction,
    :icon => :efst_noaction,
    :duration_lookup => :tk_turnkick,
    :states => [
      :nomove,
      :nopickitem,
      :nocast,
      :noattack,
      :nointeract
    ],
    :flags => [
      :noremoveondead,
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance,
      :nosave,
      :stopattacking,
      :stopcasting,
      :bossresist
    ]
  },
  %{
    :status => :c_buff_3,
    :icon => :efst_c_buff_3,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_C_BUFF_3, 1);
bonus bMaxHPrate, .@val1;
bonus bMaxSPrate, .@val1;
"
  },
  %{
    :status => :c_buff_4,
    :icon => :efst_c_buff_4,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_C_BUFF_4, 1);
bonus bFlee, .@val1;
bonus bHit, .@val1;
"
  },
  %{
    :status => :c_buff_5,
    :icon => :efst_c_buff_5,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bCritical, getstatus(SC_C_BUFF_5, 1);
bonus bAspd, getstatus(SC_C_BUFF_5, 2);
"
  },
  %{
    :status => :c_buff_6,
    :icon => :efst_c_buff_6,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_C_BUFF_6, 1);
bonus bAtkRate, .@val1;
bonus bMatkRate, .@val1;
"
  },
  %{
    :status => :contents_15,
    :icon => :efst_contents_15,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_15, 1);
bonus2 bAddEle,Ele_All, .@val1;
bonus2 bMagicAddEle,Ele_All, .@val1;
"
  },
  %{
    :status => :contents_16,
    :icon => :efst_contents_16,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_16, 1);
bonus2 bAddSize,Size_All, .@val1;
bonus2 bMagicAddSize,Size_All, .@val1;
"
  },
  %{
    :status => :contents_17,
    :icon => :efst_contents_17,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_17, 1);
bonus2 bMagicAtkEle,Ele_All, .@val1;
bonus bShortAtkRate, .@val1;
bonus bLongAtkRate, .@val1;
"
  },
  %{
    :status => :contents_18,
    :icon => :efst_contents_18,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_18, 1);
bonus bMatkRate, .@val1;
bonus bAtkRate, .@val1;
"
  },
  %{
    :status => :contents_19,
    :icon => :efst_contents_19,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => ".@val1 = getstatus(SC_CONTENTS_19, 1);
bonus bMaxHPrate, .@val1;
bonus bMaxSPrate, .@val1;
"
  },
  %{
    :status => :contents_20,
    :icon => :efst_contents_20,
    :flags => [
      :noclearbuff,
      :nodispell,
      :nobanishingbuster,
      :noclearance
    ],
    :script => "bonus bVariableCastrate, getstatus(SC_CONTENTS_20, 1);
bonus bAspd, getstatus(SC_CONTENTS_20, 2);
"
  },
  %{
    :status => :overcoming_crisis,
    :icon => :efst_overcoming_crisis,
    :duration_lookup => :hn_overcoming_crisis,
    :calc_flags => [
      :patk,
      :smatk,
      :maxhp
    ],
    :flags => [
      :nobanishingbuster,
      :nodispell,
      :noclearance
    ]
  }
]
