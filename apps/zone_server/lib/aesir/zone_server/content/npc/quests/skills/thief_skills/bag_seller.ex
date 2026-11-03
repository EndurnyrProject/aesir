defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.ThiefSkills.BagSeller do
  @moduledoc """
  RuRumuni makes a leather bag for the thief skill quest.

  ## Behavior

  - Explains the thief guild's connection to her leather bags.
  - Exchanges the requested materials for a Leather Bag of Infinity during the quest.

  ## Credits

  - Original from rAthena by kobra_k88, with contributions by L0ne_W0lf, Samuray22,
    Masao, Joseph, Lupus, Silentdragon, and IVBela.

  ## Adaptation

  - Transpiled by `mix aesir.import.npcs` from the rAthena script.
  - LLM-assisted Elixir refactor.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "payon", x: 91, y: 77, dir: 3, sprite: 99, name: "Bag Seller", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[RuRumuni]")
      |> mes("I am a humble merchant here")
      |> mes("in Payon. I buy the leather")
      |> mes("hides of animals brought in by")
      |> mes("the hunters and make leather")
      |> mes("pouches to sell. I grew up")
      |> mes("around leather working and am quite good at it.")
      |> next()

    case get_char_var(ctx, :skill_thief_1, 0) do
      0 -> explain_guild(ctx)
      1 -> make_bag(ctx)
      2 -> remind_delivery(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_guild(ctx) do
    ctx
    |> mes("[RuRumuni]")
    |> mes("There is a thief guild in the")
    |> mes("area of Morocc. I know one there")
    |> mes("that sends me thieves in need")
    |> mes("of items I make such as a")
    |> mes("^3355FF' Leather Bag of Infinity '^000000.")
    |> mes("They visit my store often.")
    |> close()
  end

  defp make_bag(ctx) do
    if count_item(ctx, 952) > 0 and count_item(ctx, 1055) > 0 and count_item(ctx, 1025) > 0 do
      ctx
      |> mes("[RuRumuni]")
      |> mes("Ahhh... You have come for a leather bag.")
      |> mes("Very good, very good.")
      |> mes("I will make you the leather bag")
      |> mes("right away if you wait just a bit.")
      |> mes("TuTak TuTak Shyuku Shyuku Shyuku")
      |> mes("- - - - -")
      |> next()
      |> mes("[RuRumuni]")
      |> mes("Okay, here it is all done.")
      |> mes("Take this leather bag")
      |> mes("to the Thief guild's Alcouskou")
      |> mes("If you take him this, he will")
      |> mes("teach you the skill that you ")
      |> mes("wish to learn.")
      |> delitem(952, 1)
      |> delitem(1055, 1)
      |> delitem(1025, 1)
      |> set_char_var(:skill_thief_1, 2)
      |> give_item(7042, 1)
      |> close()
    else
      ctx
      |> mes("[RuRumuni]")
      |> mes("Find Alcouskou of the thief guild")
      |> mes("to place and order for a leather bag of infinity.")
      |> mes("You should know that the leather bag of infinity")
      |> mes("takes much time and skill to make.")
      |> mes("In order to make such an item, you")
      |> mes("must provide me with the materials.")
      |> next()
      |> mes("The items needed as materials are")
      |> mes("these items. ..")
      |> mes("^3355FF' Earthworm Peeling '^000000")
      |> mes("^3355FF' Cobweb '^000000")
      |> mes("^3355FF' Cactus Needle '^000000")
      |> mes("I need one of each.")
      |> close()
    end
  end

  defp remind_delivery(ctx) do
    ctx
    |> mes("[RuRumuni]")
    |> mes("Here is your leather bag of infinity.")
    |> mes("Take this to the Thief guilds")
    |> mes("Alcouskou and let him know ")
    |> mes("that you are now ready to learn")
    |> mes("the skill.")
    |> close()
  end
end
