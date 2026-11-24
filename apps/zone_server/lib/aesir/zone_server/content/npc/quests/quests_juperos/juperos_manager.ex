defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.JuperosManager do
  @moduledoc """
  Lets a GM reset Juperos quest variables.

  ## Behavior

  - Requires a password and confirmation before resetting the selected variable.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "sec_in02",
        x: 39,
        y: 167,
        dir: 0,
        sprite: 864,
        name: "Juperos Manager",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> todo(:callfunc, ["F_GM_NPC"])
      |> mes("[Juperos Manager]")
      |> mes("I'm the NPC in")
      |> mes("charge of managing")
      |> mes("the global variables for")
      |> mes("the quests related to")
      |> mes("Juperos. GM, please")
      |> mes("enter the password.")
      |> next()

    if Todo.call!(:callfunc, ["F_GM_NPC", 1854, 0]) < 1 do
      ctx |> mes("[Juperos Manager]") |> mes("Incorrect password.") |> close()
    else
      choose_map(ctx)
    end
  end

  defp choose_map(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Juperos Manager]")
      |> mes("Select a map. Remember:")
      |> mes("Make sure that users aren't")
      |> mes("doing the quest on the map")
      |> mes("you're going to reset, or else")
      |> mes("you'll cancel their progress")
      |> mes("through the quest.")
      |> next()
      |> select(["jupe_Area1", "jupe_Area2", "jupe_ele_r", "jupe_ele"])

    case choice do
      1 ->
        ctx
        |> set_local(:"loc$", "jupe_Area1")
        |> set_local(:"var$", "$@JupreArea1InUse")
        |> confirm_reset()

      2 ->
        ctx
        |> set_local(:"loc$", "jupe_Area2")
        |> set_local(:"var$", "$@JupreArea2InUse")
        |> confirm_reset()

      3 ->
        ctx
        |> set_local(:"loc$", "jupe_ele_r")
        |> set_local(:"var$", "$@JupeElevatorInUse")
        |> confirm_reset()

      4 ->
        ctx
        |> set_local(:"loc$", "jupe_ele")
        |> set_local(:"var$", "$@JupeElevatorInUse2")
        |> confirm_reset()

      _ ->
        ctx
    end
  end

  defp confirm_reset(ctx) do
    ctx = ctx |> mes("[Juperos Manager]") |> mes("You've decided")

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("to reset ", get_local(ctx, :"loc$", "")), "."))
      |> mes("Shall we proceed?")
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 ->
        ctx = ctx |> mes("[Juperos Manager]") |> mes("The global variable in")

        ctx =
          ctx
          |> mes(Rathena.concat(get_local(ctx, :"loc$", ""), " has been"))
          |> mes("reset to 0. Thank you.")

        ctx |> setd(get_local(ctx, :"var$", ""), 0) |> close()

      2 ->
        ctx
        |> mes("[Juperos Manager]")
        |> mes("This command")
        |> mes("has been canceled.")
        |> close()

      _ ->
        ctx
    end
  end
end
