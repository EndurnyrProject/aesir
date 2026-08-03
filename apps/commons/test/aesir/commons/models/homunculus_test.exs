defmodule Aesir.Commons.Models.HomunculusTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus

  defp account! do
    suffix = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "homunc#{suffix}",
        user_pass: "secret",
        email: "homunc#{suffix}@example.com"
      })
      |> Repo.insert()

    account
  end

  defp character! do
    account = account!()
    suffix = System.unique_integer([:positive])

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Homunculus#{suffix}",
        class: 0
      })
      |> Repo.insert()

    character
  end

  defp attrs(character, extra \\ %{}) do
    Map.merge(
      %{
        character_id: character.id,
        class_id: 6001,
        name: "Lif",
        lifecycle: "active"
      },
      extra
    )
  end

  defp assert_constraint_error(query, params, constraint) do
    error = assert_raise Postgrex.Error, fn -> SQL.query!(Repo, query, params) end

    assert %{postgres: %{constraint: ^constraint}} = error
  end

  defp insert_homunculus_field!(character_id, field, value) do
    SQL.query!(
      Repo,
      """
      INSERT INTO homunculi (character_id, class_id, name, #{field}, inserted_at, updated_at)
      VALUES ($1, 6001, 'Lif', $2, NOW(), NOW())
      """,
      [character_id, value]
    )
  end

  defp assert_homunculus_field_constraint_error(field, value, constraint) do
    character = character!()

    error =
      assert_raise Postgrex.Error, fn ->
        insert_homunculus_field!(character.id, field, value)
      end

    assert %{postgres: %{constraint: ^constraint}} = error
  end

  test "stores one homunculus for a character" do
    character = character!()

    assert {:ok, homunculus} =
             %Homunculus{}
             |> Homunculus.changeset(attrs(character))
             |> Repo.insert()

    assert %Character{homunculus: %Homunculus{id: persisted_id}} =
             Repo.preload(character, :homunculus)

    assert persisted_id == homunculus.id
  end

  test "allows only one homunculus per character" do
    character = character!()

    assert {:ok, _homunculus} =
             %Homunculus{}
             |> Homunculus.changeset(attrs(character))
             |> Repo.insert()

    assert {:error, changeset} =
             %Homunculus{}
             |> Homunculus.changeset(attrs(character, %{name: "Amistr"}))
             |> Repo.insert()

    assert %{character_id: ["has already been taken"]} = errors_on(changeset)
  end

  test "deletes a homunculus when its character is deleted" do
    character = character!()

    assert {:ok, homunculus} =
             %Homunculus{}
             |> Homunculus.changeset(attrs(character))
             |> Repo.insert()

    assert {:ok, _character} = Repo.delete(character)
    assert Repo.get(Homunculus, homunculus.id) == nil
  end

  test "validates lifecycle, level, hunger, intimacy, and resources" do
    character = character!()

    assert Homunculus.changeset(
             %Homunculus{},
             attrs(character, %{
               lifecycle: "rested",
               level: 99,
               hunger: 100,
               intimacy_hundredths: 100_000,
               exp: 0,
               skill_points: 0,
               hp: 0,
               max_hp: 0,
               sp: 0,
               max_sp: 0,
               active_remaining_ms: 0
             })
           ).valid?

    changeset =
      Homunculus.changeset(
        %Homunculus{},
        attrs(character, %{
          lifecycle: "missing",
          level: 0,
          hunger: 101,
          intimacy_hundredths: 100_001,
          hp: -1
        })
      )

    refute changeset.valid?

    assert %{
             lifecycle: ["is invalid"],
             level: ["must be greater than or equal to 1"],
             hunger: ["must be less than or equal to 100"],
             intimacy_hundredths: ["must be less than or equal to 100000"],
             hp: ["must be greater than or equal to 0"]
           } = errors_on(changeset)
  end

  test "accepts both exact intimacy bounds" do
    character = character!()

    for intimacy_hundredths <- [0, 100_000] do
      assert Homunculus.changeset(
               %Homunculus{},
               attrs(character, %{intimacy_hundredths: intimacy_hundredths})
             ).valid?
    end
  end

  test "bounds each persisted map to 64 entries" do
    character = character!()

    for field <- [:learned_skills, :cooldowns, :ai_config] do
      assert Homunculus.changeset(
               %Homunculus{},
               attrs(character, %{field => Map.new(1..64, &{Integer.to_string(&1), 1})})
             ).valid?

      changeset =
        Homunculus.changeset(
          %Homunculus{},
          attrs(character, %{field => Map.new(1..65, &{Integer.to_string(&1), 1})})
        )

      refute changeset.valid?
      assert %{^field => ["must be a map with at most 64 entries"]} = errors_on(changeset)
    end
  end

  test "database constraints admit exact numeric endpoints" do
    for {field, endpoints} <- [
          level: [1, 99],
          hunger: [0, 100],
          intimacy_hundredths: [0, 100_000]
        ],
        value <- endpoints do
      character = character!()

      assert %Postgrex.Result{num_rows: 1} =
               insert_homunculus_field!(character.id, field, value)
    end
  end

  test "database constraints reject numeric values outside their bounds" do
    for {field, values, constraint} <- [
          {:level, [0, 100], "homunculi_level_check"},
          {:hunger, [-1, 101], "homunculi_hunger_check"},
          {:intimacy_hundredths, [-1, 100_001], "homunculi_intimacy_hundredths_check"}
        ],
        value <- values do
      assert_homunculus_field_constraint_error(field, value, constraint)
    end
  end

  test "database resource constraint rejects each negative resource" do
    for field <- [:exp, :skill_points, :hp, :max_hp, :sp, :max_sp, :active_remaining_ms] do
      assert_homunculus_field_constraint_error(field, -1, "homunculi_resources_non_negative")
    end
  end

  test "database lifecycle constraint rejects invalid durable state" do
    character = character!()

    assert_constraint_error(
      """
      INSERT INTO homunculi (character_id, class_id, name, lifecycle, inserted_at, updated_at)
      VALUES ($1, 6001, 'Lif', 'missing', NOW(), NOW())
      """,
      [character.id],
      "homunculi_lifecycle_check"
    )
  end

  test "database constraints require bounded map objects" do
    character = character!()

    for field <- ~w(learned_skills cooldowns ai_config) do
      assert_constraint_error(
        """
        INSERT INTO homunculi (character_id, class_id, name, #{field}, inserted_at, updated_at)
        VALUES ($1, 6001, 'Lif', '[]'::jsonb, NOW(), NOW())
        """,
        [character.id],
        "homunculi_#{field}_is_object"
      )

      assert_constraint_error(
        """
        INSERT INTO homunculi (character_id, class_id, name, #{field}, inserted_at, updated_at)
        SELECT $1, 6001, 'Lif', jsonb_object_agg(i::text, i), NOW(), NOW()
        FROM generate_series(1, 65) AS i
        """,
        [character.id],
        "homunculi_#{field}_is_object"
      )
    end
  end
end
