defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Grave do
  @moduledoc """
  The grave conceals the entrance to the robot factory.

  ## Behavior

  - Accepts the Yellow Keycard name and password to unlock the entrance.
  - Transfers adventurers through the open entrance or accepts a Luxurious Keycard after the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_fild08",
        x: 71,
        y: 170,
        dir: 0,
        sprite: 111,
        name: "Grave",
        scope: :shared,
        unique_name: "Grave#kh"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest_stage = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      quest_stage < 36 -> ordinary_grave(ctx)
      quest_stage == 36 -> unlock_entrance(ctx)
      quest_stage >= 38 and quest_stage < 106 -> enter_factory(ctx)
      quest_stage >= 106 -> use_luxurious_keycard(ctx)
      true -> ctx
    end
  end

  defp ordinary_grave(ctx) do
    ctx
    |> mes("^3355FFIt's just a grave.")
    |> mes("It might be important")
    |> mes("to you later, but now")
    |> mes("it's not really all that")
    |> mes("helpful to you.^000000")
    |> close()
  end

  defp unlock_entrance(ctx) do
    if count_item(ctx, 7492) < 1 do
      ordinary_grave(ctx)
    else
      insert_keycard(ctx)
    end
  end

  defp insert_keycard(ctx) do
    {ctx, keycard_name} =
      ctx
      |> mes("^3355FFThere's a secret door")
      |> mes("near this grave. It looks")
      |> mes("like there's some kind of")
      |> mes("slot and a number pad")
      |> mes("installed on the door.^000000")
      |> next()
      |> mes("^3355FFWhat should you")
      |> mes("insert into the slot?^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"KHInput$", keycard_name)

    if get_local(ctx, :"KHInput$", "") == "Yellow Keycard" do
      enter_password(ctx)
    else
      ctx
      |> mes("^3355FFWhatever you're trying")
      |> mes("to insert into the slot")
      |> mes("isn't working at all...^000000")
      |> close()
    end
  end

  defp enter_password(ctx) do
    {ctx, password} =
      ctx
      |> mes("^3355FFAn electronic confirmation")
      |> mes("chime sounds once you insert")
      |> mes("the Yellow Keycard, followed by")
      |> mes("an automated voice that asks:^000000")
      |> next()
      |> mes("[Security System]")
      |> mes("Please enter the password.")
      |> next()
      |> input(:string)

    ctx = ctx |> set_local(:"KHInput$", password) |> next()

    if get_local(ctx, :"KHInput$", "") == "4772961" do
      ctx
      |> mes("[Security System]")
      |> mes("Password confirmed.")
      |> mes("Welcome, Kiel Hyre.")
      |> next()
      |> mes("^3355FFYou hear another ")
      |> mes("pleasant beep, and")
      |> mes("a secret path opens.^000000")
      |> set_char_var(:KielHyreQuest, 38)
      |> close()
    else
      ctx
      |> mes("[Security System]")
      |> mes("Incorrect password.")
      |> mes("Please try again.")
      |> close()
    end
  end

  defp enter_factory(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThe door to the")
      |> mes("factory is wide open.^000000")
      |> next()
      |> select(["Enter", "Cancel"])

    choose_entrance(ctx, choice)
  end

  defp use_luxurious_keycard(ctx) do
    if count_item(ctx, 7509) < 1 do
      ctx
      |> mes("^3355FFThe secret entrance")
      |> mes("has now been sealed.^000000")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> mes("As you aproach the")
        |> mes("grave, it begins to")
        |> mes("emit flashes of light.^000000")
        |> next()
        |> select(["Use the ^0000FFLuxurious Keycard^000000", "Ignore"])

      case choice do
        1 -> open_secret_path(ctx)
        2 -> decline_entrance(ctx)
        _ -> ctx
      end
    end
  end

  defp open_secret_path(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Once you use the")
      |> mes("Luxurious Keycard,")
      |> mes("a secret path opens^000000")
      |> next()
      |> select(["Enter", "cancel"])

    choose_entrance(ctx, choice)
  end

  defp choose_entrance(ctx, choice) do
    case choice do
      1 -> warp(ctx, "kh_dun01", 3, 230)
      2 -> decline_entrance(ctx)
      _ -> ctx
    end
  end

  defp decline_entrance(ctx) do
    ctx |> mes("......") |> mes(".........") |> mes("............") |> close()
  end
end
