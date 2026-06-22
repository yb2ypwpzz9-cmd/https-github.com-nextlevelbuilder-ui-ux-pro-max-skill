const https = require('https');

const ICAL_URL = 'https://www.airbnb.com/calendar/ical/1709385271951500620.ics?t=a2d42a8648e74823a1bc22f4ee7ed09b&locale=es';

function fetchIcal(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
      res.on('error', reject);
    }).on('error', reject);
  });
}

function parseIcal(text) {
  const blocked = [];
  const events = text.split('BEGIN:VEVENT');

  for (let i = 1; i < events.length; i++) {
    const block = events[i];
    const dtstart = block.match(/DTSTART[^:]*:(\d{8})/);
    const dtend = block.match(/DTEND[^:]*:(\d{8})/);

    if (dtstart && dtend) {
      const start = dtstart[1];
      const end = dtend[1];

      // Generate all dates in range
      let current = new Date(
        parseInt(start.slice(0,4)),
        parseInt(start.slice(4,6)) - 1,
        parseInt(start.slice(6,8))
      );
      const endDate = new Date(
        parseInt(end.slice(0,4)),
        parseInt(end.slice(4,6)) - 1,
        parseInt(end.slice(6,8))
      );

      while (current < endDate) {
        const y = current.getFullYear();
        const m = String(current.getMonth() + 1).padStart(2, '0');
        const d = String(current.getDate()).padStart(2, '0');
        blocked.push(`${y}-${m}-${d}`);
        current.setDate(current.getDate() + 1);
      }
    }
  }

  return [...new Set(blocked)];
}

exports.handler = async () => {
  try {
    const ical = await fetchIcal(ICAL_URL);
    const blocked = parseIcal(ical);

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=3600'
      },
      body: JSON.stringify({ blocked })
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Error fetching calendar', blocked: [] })
    };
  }
};
