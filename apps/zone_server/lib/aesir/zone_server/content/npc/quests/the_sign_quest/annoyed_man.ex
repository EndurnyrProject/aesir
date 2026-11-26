defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.AnnoyedMan do
  @moduledoc """
  Dhota helps direct adventurers seeking Metz Brayde.

  ## Behavior

  - At the appropriate quest stage, a recognized answer reveals Metz’s whereabouts.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "gef_tower", x: 118, y: 36, dir: 4, sprite: 64, name: "Annoyed Man", scope: :shared}
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Dhota]")

    if get_char_var(ctx, :sign_q, 0) == 72 do
      ask_about_metz(ctx)
    else
      ctx
      |> mes("Hmmm...")
      |> mes("That can't be right...")
      |> mes("What could possibly be")
      |> mes("the answer I'm looking")
      |> mes("for? ^333333*Sigh...*^000000")
      |> emotion(:hng)
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_metz(ctx) do
    ctx =
      if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:mage) do
        ctx |> mes("Wah~") |> mes("Why the hell did he even go there...!")
      else
        ctx
        |> mes("You're not even a Mage,")
        |> mes("much less a Wizard, Sage, Warlock or a Sorcerer.")
        |> mes("Why bother climbing this tower?")
      end

    {ctx, answer} =
      ctx |> mes("What are you doing here?!") |> emotion(:hng) |> next() |> input(:string)

    case answer do
      answer when answer in ["Metz Brayde", "Sobbing Starlight"] ->
        ctx = ctx |> mes("[Dhota]") |> mes("Eh?")

        ctx =
          if answer == "Metz Brayde" do
            ctx |> mes("Did you just say you're") |> mes("here for Metz Brayde?")
          else
            mes(ctx, "For that Sobbing Starlight, is that right?")
          end

        ctx
        |> next()
        |> mes("[Dhota]")
        |> mes("...")
        |> emotion(:think)
        |> next()
        |> mes("[Dhota]")
        |> mes("...")
        |> mes("......")
        |> emotion(:think)
        |> next()
        |> mes("[Dhota]")
        |> mes("...")
        |> mes("......")
        |> mes("BWAAAAH~!")
        |> emotion(:anger)
        |> next()
        |> mes("[Dhota]")
        |> mes("Right, he wants that guy")
        |> mes("who's good at working with")
        |> mes("gems and stuff. Eh, he's not")
        |> mes("here right now. Went somewhere")
        |> mes("near Comodo to investigate some")
        |> mes("tribal people or whatever.")
        |> set_char_var(:sign_q, 73)
        |> emotion(:hng)
        |> close()

      _ ->
        ctx
        |> mes("[Dhota]")
        |> mes("Say what...?")
        |> mes("I have no idea what")
        |> mes("you're talking about!")
        |> mes("If you've got nothing")
        |> mes("to say, then leave me alone!")
        |> close()
    end
  end
end
