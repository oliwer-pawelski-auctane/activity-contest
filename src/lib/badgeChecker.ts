import { supabase } from "@/lib/supabase";
import type { Activity, Badge } from "@/lib/types";

export async function checkAndAwardBadges(personId: string): Promise<string[]> {
  // Fetch current data
  const [activitiesRes, badgesRes, earnedRes] = await Promise.all([
    supabase.from("activities").select("*").eq("person_id", personId).order("created_at"),
    supabase.from("badges").select("*"),
    supabase.from("user_badges").select("badge_id").eq("person_id", personId),
  ]);

  const activities = (activitiesRes.data as Activity[]) ?? [];
  const allBadges = (badgesRes.data as Badge[]) ?? [];
  const earnedIds = new Set((earnedRes.data ?? []).map((e: { badge_id: number }) => e.badge_id));

  const totalPoints = activities.reduce((s, a) => s + a.points, 0);
  const proofCount = activities.filter((a) => a.proof_url).length;
  const uniqueTypes = new Set(activities.map((a) => a.activity_type_id)).size;

  // Calculate streak
  const uniqueDays = [...new Set(activities.map((a) => new Date(a.created_at).toDateString()))];
  const sortedDays = uniqueDays.map((d) => new Date(d)).sort((a, b) => b.getTime() - a.getTime());
  let streak = 0;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  for (let i = 0; i < sortedDays.length; i++) {
    const expected = new Date(today);
    expected.setDate(expected.getDate() - i);
    expected.setHours(0, 0, 0, 0);
    const day = new Date(sortedDays[i]);
    day.setHours(0, 0, 0, 0);
    if (day.getTime() === expected.getTime()) streak++;
    else break;
  }

  // Check person has a team
  const { data: person } = await supabase.from("people").select("team_id").eq("id", personId).maybeSingle();
  const hasTeam = person?.team_id != null;

  // Determine which badges to award
  const checks: Record<string, boolean> = {
    first_activity: activities.length > 0,
    streak_3: streak >= 3,
    streak_7: streak >= 7,
    streak_14: streak >= 14,
    streak_30: streak >= 30,
    points_10: totalPoints >= 10,
    points_50: totalPoints >= 50,
    points_100: totalPoints >= 100,
    points_500: totalPoints >= 500,
    proof_5: proofCount >= 5,
    proof_20: proofCount >= 20,
    variety_3: uniqueTypes >= 3,
    team_player: hasTeam,
  };

  const newBadges: string[] = [];

  for (const badge of allBadges) {
    if (earnedIds.has(badge.id)) continue;
    if (checks[badge.key]) {
      const { error } = await supabase.from("user_badges").insert({
        person_id: personId,
        badge_id: badge.id,
      });
      if (!error) newBadges.push(badge.name);
    }
  }

  return newBadges;
}
