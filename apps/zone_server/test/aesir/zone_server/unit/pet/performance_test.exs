defmodule Aesir.ZoneServer.Unit.Pet.PerformanceTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Pet.PetState

  test "performance roll respects intimacy and special performances" do
    pet =
      struct!(PetState,
        pet_id: 1,
        owner_char_id: 1,
        owner_account_id: 1,
        class_id: 1002,
        mob_db_id: 1002,
        name: "Poring",
        level: 1,
        egg_id: 1,
        intimate: 950,
        hungry: 1
      )

    definition = build(:pet_definition)

    for {intimacy, special, expected} <- [
          {950, true, 4},
          {950, false, 3},
          {800, false, 2},
          {500, false, 1}
        ] do
      assert CommandHandler.performance_value(
               %{pet | intimate: intimacy},
               %{definition | special_performance: special},
               fn max -> max end
             ) == expected
    end
  end
end
