defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BlacksmithCatalogTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter

  @blacksmith_skills [
    {94, :bs_iron},
    {95, :bs_steel},
    {96, :bs_enchantedstone},
    {97, :bs_orideocon},
    {98, :bs_dagger},
    {99, :bs_sword},
    {100, :bs_twohandsword},
    {101, :bs_axe},
    {102, :bs_mace},
    {103, :bs_knuckle},
    {104, :bs_spear},
    {105, :bs_hiltbinding},
    {106, :bs_findingore},
    {107, :bs_weaponresearch},
    {108, :bs_repairweapon},
    {109, :bs_skintemper},
    {110, :bs_hammerfall},
    {111, :bs_adrenaline},
    {112, :bs_weaponperfect},
    {113, :bs_overthrust},
    {114, :bs_maximize},
    {459, :bs_adrenaline2},
    {1012, :bs_unfairlytrick},
    {1013, :bs_greed}
  ]

  setup do
    :ok = Catalog.reload()
  end

  test "catalog resolves every Blacksmith skill by id and name" do
    for {id, name} <- @blacksmith_skills do
      assert {:ok, %{id: ^id, name: ^name}} = Catalog.by_id(id)
      assert {:ok, %{id: ^id, name: ^name}} = Catalog.by_name(name)
    end
  end

  test "casting inert phase-2 skills safely returns capability errors" do
    game_state = %{stats: %{progression: %{learned_skills: %{105 => 1, 111 => 1}}}}

    assert {:error, :passive_skill} = Interpreter.cast(game_state, 105, 1, :self)
    assert {:error, :no_behavior} = Interpreter.cast(game_state, 111, 1, :self)
  end
end
