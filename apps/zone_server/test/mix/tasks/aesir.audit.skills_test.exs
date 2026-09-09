defmodule Mix.Tasks.Aesir.Audit.SkillsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Mix.Tasks.Aesir.Audit.Skills, as: Task

  describe "parse_args!/1" do
    test "requires --job" do
      assert_raise Mix.Error, ~r/--job is required/, fn ->
        Task.parse_args!(["~/rathena"])
      end
    end

    test "defaults the mode to renewal" do
      assert {"~/rathena", :renewal, :swordman} =
               Task.parse_args!(["~/rathena", "--job", "swordman"])
    end

    test "accepts --mode re and --mode pre-re" do
      assert {_rathena, :renewal, :swordman} =
               Task.parse_args!(["~/rathena", "--mode", "re", "--job", "swordman"])

      assert {_rathena, :pre_renewal, :swordman} =
               Task.parse_args!(["~/rathena", "--mode", "pre-re", "--job", "swordman"])
    end

    test "raises on an invalid --mode" do
      assert_raise Mix.Error, ~r/invalid --mode/, fn ->
        Task.parse_args!(["~/rathena", "--mode", "classic", "--job", "swordman"])
      end
    end

    test "raises on an unknown job" do
      assert_raise Mix.Error, ~r/unknown job/, fn ->
        Task.parse_args!(["~/rathena", "--job", "not_a_real_job"])
      end
    end
  end

  describe "render_report/3" do
    test "renders a heading, an empty table note, and no suggestions when nothing differs" do
      results = [
        {:ok, :sm_bash, %Definition{id: 5, name: :sm_bash, display_name: "Bash", max_level: 10},
         [], []}
      ]

      report = Task.render_report(:swordman, :renewal, results)

      assert report =~ "# Skill audit: swordman (renewal)"
      assert report =~ "No strict mismatches."
      refute report =~ "```elixir"
    end

    test "renders a mismatch row and a suggestion block for a differing skill" do
      definition = %Definition{
        id: 5,
        name: :sm_bash,
        display_name: "Bash",
        max_level: 10,
        range: -1
      }

      findings = [%{field: :range, aesir: -1, source: 9}]
      results = [{:ok, :sm_bash, definition, findings, []}]

      report = Task.render_report(:swordman, :renewal, results)

      assert report =~ "| sm_bash | range | -1 | 9 |"
      assert report =~ "## sm_bash"
      assert report =~ "```elixir\nrange: 9\n```"
    end

    test "renders a missing-in-source skill as a strict row" do
      results = [{:missing, :sm_ghost}]

      report = Task.render_report(:swordman, :renewal, results)

      assert report =~ "| sm_ghost | - | - | missing in source |"
    end

    test "renders a renewal-only skill as informational, not in the strict table" do
      results = [{:renewal_only, :sm_ghost}]

      report = Task.render_report(:swordman, :pre_renewal, results)

      assert report =~ "No strict mismatches."
      assert report =~ "`sm_ghost`: renewal-only"
    end

    test "renders a skill's notes as informational, without affecting the strict table" do
      definition = %Definition{id: 5, name: :sm_bash, display_name: "Bash", max_level: 10}
      notes = ["negative source HitCount values: [-3, -3]"]
      results = [{:ok, :sm_bash, definition, [], notes}]

      report = Task.render_report(:swordman, :renewal, results)

      assert report =~ "No strict mismatches."
      assert report =~ "`sm_bash`: negative source HitCount values: [-3, -3]"
    end
  end
end
