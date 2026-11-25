defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.MoroccGlobalvarAdminMoroccadminSec do
  @moduledoc """
  A password-protected administrator displays and resets Morocc's event state.

  ## Behavior

  - Shows the current event state and permits resets from the field placement.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        x: 14,
        y: 43,
        dir: 5,
        sprite: 971,
        name: "Morocc GlobalVar Admin",
        scope: :shared,
        unique_name: "MoroccAdmin_sec"
      },
      %{
        map: "moc_fild21",
        x: 5,
        y: 5,
        dir: 5,
        sprite: 971,
        name: "Morocc GlobalVar Admin",
        scope: :shared,
        unique_name: "MoroccAdmin_moc"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> todo(:callfunc, ["F_GM_NPC"])
      |> mes("[Helper]")
      |> mes("Please enter the password and # button.")
      |> next()

    if Todo.call!(:callfunc, ["F_GM_NPC", 1854, 0]) < 1 do
      ctx |> mes("[Helper]") |> mes("Please press the numbers we always sing about.") |> close()
    else
      show_status(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp show_status(ctx) do
    ctx =
      ctx
      |> mes("[Helper]")
      |> mes("Hello. I am a post office.")
      |> mes("I am currently checking Morocc status.")
      |> next()
      |> mes("=============")
      |> mes("Current State")
      |> mes("=============")
      |> mes("^3131FF<Morocc>^000000")
      |> describe_status()

    {ctx, choice} =
      ctx
      |> next()
      |> mes("[Helper]")
      |> mes("What do you want?")
      |> next()
      |> select(["Cancel.", "Reset"])

    case choice do
      1 -> ctx |> mes("[Helper]") |> mes("Alright.") |> close()
      2 -> reset(ctx)
      _ -> ctx
    end
  end

  defp describe_status(ctx) do
    case get_server_temp_var(ctx, "re_moc", 0) do
      0 ->
        ctx
        |> mes("Reset. Enable to summon Morocc.")
        |> mes("^3131FF<Continental Guards>^000000")
        |> mes("Enable to enter to moc_fild21 field.")

      1 ->
        ctx
        |> mes("^3131FF<Morocc>^000000")
        |> mes(
          "Some warrior entered after the reset. However, the warrior hasn't started the quest yet."
        )
        |> mes("The warrior who has rebirth_moc_edq 4 and 7 is now enabled to summon Morocc.")
        |> mes("^3131FF<Continental Guards>^000000")
        |> mes("The warrior who has rebirth_moc_edq 4 ~ 7 is now enabled to enter to moc_fild21.")

      2 ->
        ctx
        |> mes("^3131FF<Morocc>^000000")
        |> mes(
          "Morocc has been summoned. After 90 minutes has passed, it will revert back to reset status."
        )
        |> mes("^3131FF<Continental Guards>^000000")
        |> mes("The warrior who has rebirth_moc_edq 4 ~ 7 is now enabled to enter to moc_fild21.")

      state ->
        ctx = mes(ctx, "^3131FF<Morocc>^000000")

        ctx =
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat(
                "Morocc has been killed. Death time is ",
                get_server_temp_var(ctx, "re_moc_time$", "")
              ),
              "(00 hr/00 min/00 sec)."
            )
          )
          |> mes("After 6 hours later since the death time, it will be reset.")

        ctx =
          if state == 3 do
            mes(
              ctx,
              "The warriors whom has remained in the field can continue the quest via Time Space Gap."
            )
          else
            mes(
              ctx,
              "It has been already passed 30 minutes after Morocc's death, so warriors can not continue the quest even if they click the Time Space Gap."
            )
          end

        ctx
        |> mes("^3131FF<Continental Guards>^000000")
        |> mes("Disabled to enter to moc_fild21 from outside of the field.")
    end
  end

  defp reset(ctx) do
    ctx =
      if strnpcinfo(ctx, 4) == "sec_in02" do
        mes(ctx, "You can reset at moc_fild21 5 5.")
      else
        ctx
        |> mes("Reset starts.")
        |> next()
        |> donpcevent("Group of Evil#edq::OnEnable")
        |> mes("Group of Evil NPC is appeared.")
        |> mes("Time-Space Gap NPC is disappeared.")
        |> mes("6 hours term timer is stopped.")
        |> donpcevent("Satan Summon#edq::OnDisable")
        |> mes("Morocc 90 minutes survival timer is stopped.")
        |> mes("Morocc is being killed.")
        |> mes("Now, Continental Guards will let players enter.")
      end

    close(ctx)
  end
end
